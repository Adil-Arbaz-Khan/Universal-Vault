# Universal Vault V5 (Enterprise Grade) PowerShell Engine
# Authenticated In-Place Stream Encryption (AES-256-CTR + HMAC-SHA256)
# Fault-Tolerant Resumable & Rollback In-Place Checkpoint Architecture with Hardware Flush Barrier
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("Lock", "Unlock", "Status")]
    [string]$Action = "Status",

    [Parameter(Position=1)]
    [string]$Path = ".",

    [Parameter(Position=2)]
    [string]$Password,

    [Parameter(Position=3)]
    [switch]$Gibberish
)

$MAGIC_V5 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV05")
$MAGIC_V4 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV04")
$MAGIC_V3 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV03")
$MAGIC_V2 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV02")
$MAGIC_V1 = [System.Text.Encoding]::ASCII.GetBytes("HDRLOK01")

$FOOTER_LEN_V5_RESUMABLE = 104
$FOOTER_LEN_V5_BASE = 96
$FOOTER_LEN_V4 = 80
$FOOTER_LEN_V3 = 80
$FOOTER_LEN_V2 = 76

$CHUNK_SIZE_V5 = 65536  # 64 KB streaming chunks
$KDF_ITERS_V5 = 600000  # OWASP 2026 Gold Standard (600,000 rounds)

$STATE_NORMAL_LOCKED = 0
$STATE_LOCK_IN_PROGRESS = 1
$STATE_UNLOCK_IN_PROGRESS = 2
$FLAG_GIBBERISH_NAME = 4

# Compile high-performance C# AES-CTR processor for 100x speedup
if (-not ([System.Management.Automation.PSTypeName]'VaultFastCtr').Type) {
    $csharpCode = @"
using System;
using System.Security.Cryptography;

public static class VaultFastCtr {
    public static void ProcessChunk(ICryptoTransform encryptor, byte[] nonce, byte[] buffer, int offset, int count, long startBlockIdx) {
        byte[] counterBlock = new byte[16];
        byte[] keystream = new byte[16];
        Array.Copy(nonce, 0, counterBlock, 0, 16);

        ulong baseLow = BitConverter.ToUInt64(nonce, 8);
        if (BitConverter.IsLittleEndian) {
            byte[] b = BitConverter.GetBytes(baseLow);
            Array.Reverse(b);
            baseLow = BitConverter.ToUInt64(b, 0);
        }

        int blocks = (count + 15) / 16;
        for (int b = 0; b < blocks; b++) {
            ulong curVal = baseLow + (ulong)(startBlockIdx + b);
            byte[] curBytes = BitConverter.GetBytes(curVal);
            if (BitConverter.IsLittleEndian) {
                Array.Reverse(curBytes);
            }
            Array.Copy(curBytes, 0, counterBlock, 8, 8);

            encryptor.TransformBlock(counterBlock, 0, 16, keystream, 0);

            int blockOff = b * 16;
            int take = Math.Min(16, count - blockOff);
            for (int i = 0; i < take; i++) {
                buffer[offset + blockOff + i] ^= keystream[i];
            }
        }
    }
}
"@
    Add-Type -TypeDefinition $csharpCode -Language CSharp
}

function Sync-FileToDisk($fs) {
    try {
        $fs.Flush($true)
    } catch {
        $fs.Flush()
    }
}

function Format-Eta([double]$seconds) {
    if ($seconds -lt 0 -or $seconds -gt 86400) { return "--:--" }
    $ts = [TimeSpan]::FromSeconds($seconds)
    if ($ts.Hours -gt 0) { return $ts.ToString("hh\:mm\:ss") }
    return $ts.ToString("mm\:ss")
}

function Render-Progress([string]$filename, [long]$currBytes, [long]$totBytes, [System.Diagnostics.Stopwatch]$sw) {
    if ($totBytes -lt (5 * 1024 * 1024)) { return }
    $elapsedSec = [Math]::Max(0.001, ($sw.ElapsedMilliseconds / 1000.0))
    $speedBytes = $currBytes / $elapsedSec
    $speedMb = [Math]::Round($speedBytes / (1024 * 1024), 1)
    $percent = [Math]::Min(100.0, ($currBytes / [double]$totBytes) * 100)

    $remBytes = [Math]::Max(0, $totBytes - $currBytes)
    $etaSec = if ($speedBytes -gt 0) { $remBytes / $speedBytes } else { 0 }
    $etaStr = Format-Eta $etaSec

    $barWidth = 24
    $filled = [int]($barWidth * ($percent / 100.0))
    $empty = $barWidth - $filled
    $bar = ("#" * $filled) + ("-" * $empty)

    $currMb = [Math]::Round($currBytes / (1024 * 1024), 1)
    $totMb = [Math]::Round($totBytes / (1024 * 1024), 1)

    $shortName = if ($filename.Length -le 20) { $filename } else { $filename.Substring(0, 17) + "..." }
    $line = "`r  [$shortName] [$bar] {0,5:F1}% | {1,6:F1}/{2,6:F1} MB | {3,5:F1} MB/s | ETA: {4} " -f $percent, $currMb, $totMb, $speedMb, $etaStr
    Write-Host -NoNewline $line
}

function Get-KeysV5($pass, $salt) {
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pass, $salt, $KDF_ITERS_V5, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $dk = $kdf.GetBytes(64)
    $encKey = New-Object byte[] 32
    $macKey = New-Object byte[] 32
    [Array]::Copy($dk, 0, $encKey, 0, 32)
    [Array]::Copy($dk, 32, $macKey, 0, 32)

    $hmac = [System.Security.Cryptography.HMACSHA256]::new($macKey)
    $tagData = [System.Text.Encoding]::ASCII.GetBytes("VAULT_AUTH_V5") + $salt
    $fullTag = $hmac.ComputeHash($tagData)
    $authTag = New-Object byte[] 16
    [Array]::Copy($fullTag, 0, $authTag, 0, 16)

    return @{ EncKey = $encKey; MacKey = $macKey; AuthTag = $authTag }
}

function Get-LegacyKey($pass, $salt, $version = 4) {
    $iters = if ($version -ge 3) { 100000 } else { 10000 }
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pass, $salt, $iters, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $key = $kdf.GetBytes(32)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $tag = if ($version -eq 4) { [System.Text.Encoding]::ASCII.GetBytes("VAULT_AUTH_V4") } elseif ($version -eq 3) { [System.Text.Encoding]::ASCII.GetBytes("VAULT_AUTH_V3") } elseif ($version -eq 2) { [System.Text.Encoding]::ASCII.GetBytes("VAULT_AUTH_V2") } else { [System.Text.Encoding]::ASCII.GetBytes("AUTH_CHECK_V1") }
    $authInput = $key + $tag + $salt
    $authHash = $sha.ComputeHash($authInput)
    return @{ Key = $key; AuthHash = $authHash }
}

function Read-FileFooter($fs) {
    if ($fs.Length -ge $FOOTER_LEN_V5_RESUMABLE) {
        $fs.Seek(-$FOOTER_LEN_V5_RESUMABLE, [System.IO.SeekOrigin]::End) | Out-Null
        $chk = New-Object byte[] 8
        $fs.Read($chk, 0, 8) | Out-Null
        if ([System.Text.Encoding]::ASCII.GetString($chk) -eq "VAULTV05") {
            $fs.Seek(-$FOOTER_LEN_V5_RESUMABLE, [System.IO.SeekOrigin]::End) | Out-Null
            $buf = New-Object byte[] $FOOTER_LEN_V5_RESUMABLE
            $fs.Read($buf, 0, $FOOTER_LEN_V5_RESUMABLE) | Out-Null
            return @{ Version = 5; Footer = $buf; Length = $FOOTER_LEN_V5_RESUMABLE }
        }
    }
    if ($fs.Length -ge $FOOTER_LEN_V5_BASE) {
        $fs.Seek(-$FOOTER_LEN_V5_BASE, [System.IO.SeekOrigin]::End) | Out-Null
        $chk = New-Object byte[] 8
        $fs.Read($chk, 0, 8) | Out-Null
        if ([System.Text.Encoding]::ASCII.GetString($chk) -eq "VAULTV05") {
            $fs.Seek(-$FOOTER_LEN_V5_BASE, [System.IO.SeekOrigin]::End) | Out-Null
            $buf = New-Object byte[] $FOOTER_LEN_V5_BASE
            $fs.Read($buf, 0, $FOOTER_LEN_V5_BASE) | Out-Null
            return @{ Version = 5; Footer = $buf; Length = $FOOTER_LEN_V5_BASE }
        }
    }
    if ($fs.Length -ge $FOOTER_LEN_V4) {
        $fs.Seek(-$FOOTER_LEN_V4, [System.IO.SeekOrigin]::End) | Out-Null
        $chk = New-Object byte[] 8
        $fs.Read($chk, 0, 8) | Out-Null
        $m = [System.Text.Encoding]::ASCII.GetString($chk)
        if ($m -eq "VAULTV04" -or $m -eq "VAULTV03") {
            $fs.Seek(-$FOOTER_LEN_V4, [System.IO.SeekOrigin]::End) | Out-Null
            $buf = New-Object byte[] $FOOTER_LEN_V4
            $fs.Read($buf, 0, $FOOTER_LEN_V4) | Out-Null
            $v = if ($m -eq "VAULTV04") { 4 } else { 3 }
            return @{ Version = $v; Footer = $buf; Length = $FOOTER_LEN_V4 }
        }
    }
    if ($fs.Length -ge $FOOTER_LEN_V2) {
        $fs.Seek(-$FOOTER_LEN_V2, [System.IO.SeekOrigin]::End) | Out-Null
        $chk = New-Object byte[] 8
        $fs.Read($chk, 0, 8) | Out-Null
        $str = [System.Text.Encoding]::ASCII.GetString($chk)
        if ($str -eq "VAULTV02" -or $str -eq "HDRLOK01") {
            $fs.Seek(-$FOOTER_LEN_V2, [System.IO.SeekOrigin]::End) | Out-Null
            $buf = New-Object byte[] $FOOTER_LEN_V2
            $fs.Read($buf, 0, $FOOTER_LEN_V2) | Out-Null
            $v = if ($str -eq "VAULTV02") { 2 } else { 1 }
            return @{ Version = $v; Footer = $buf; Length = $FOOTER_LEN_V2 }
        }
    }

    # Partial footer recovery for sudden power loss during initial footer append
    if ($fs.Length -ge 16) {
        $scanLen = [Math]::Min(256L, $fs.Length)
        $fs.Seek(-$scanLen, [System.IO.SeekOrigin]::End) | Out-Null
        $scanBuf = New-Object byte[] $scanLen
        $fs.Read($scanBuf, 0, $scanLen) | Out-Null
        $scanStr = [System.Text.Encoding]::ASCII.GetString($scanBuf)
        $idx = $scanStr.LastIndexOf("VAULTV05")
        if ($idx -ge 0) {
            $damagedOffset = $fs.Length - $scanLen + $idx
            if ($fs.CanWrite) {
                try {
                    $fs.SetLength($damagedOffset)
                    Sync-FileToDisk $fs
                } catch {}
            }
            return @{ Version = "Damaged"; Offset = $damagedOffset }
        }
    }

    return $null
}

function Check-FileLockStatus($filePath) {
    try {
        $fi = New-Object System.IO.FileInfo($filePath)
        if ($fi.Length -lt $FOOTER_LEN_V2) { return "unlocked" }
        $fs = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $finfo = Read-FileFooter $fs
            if ($finfo) {
                if ($finfo.Version -eq "Damaged") {
                    return "unlocked (partial initial header detected - self-heals on lock)"
                }
                if ($finfo.Version -eq 5) {
                    if ($finfo.Length -eq $FOOTER_LEN_V5_RESUMABLE) {
                        $checkpoint = [BitConverter]::ToUInt64($finfo.Footer, 92)
                        $fails = [BitConverter]::ToUInt16($finfo.Footer, 100)
                        $state = [BitConverter]::ToUInt16($finfo.Footer, 102)
                        if (($state -band 3) -eq $STATE_UNLOCK_IN_PROGRESS) {
                            return "locked (V5 RESUMABLE UNLOCK INTERRUPTED at $([Math]::Round($checkpoint/1MB, 2)) MB)"
                        } elseif (($state -band 3) -eq $STATE_LOCK_IN_PROGRESS) {
                            return "locked (V5 RESUMABLE LOCK INTERRUPTED at $([Math]::Round($checkpoint/1MB, 2)) MB)"
                        }
                    } else {
                        $fails = [BitConverter]::ToUInt16($finfo.Footer, 92)
                        $state = [BitConverter]::ToUInt16($finfo.Footer, 94)
                    }

                    $lbl = "V5 Authenticated AEAD (100% Full-File)"
                    if (($state -band $FLAG_GIBBERISH_NAME) -ne 0) { $lbl += " [Gibberish Name]" }
                    if ($fails -ge 5) { return "locked ($lbl - LOCKOUT: $fails fails)" }
                    return "locked ($lbl)"
                }
                return "locked (Legacy V$($finfo.Version))"
            }
            return "unlocked"
        } finally {
            $fs.Close()
        }
    } catch {
        return "error"
    }
}

function Lock-FileV5($filePath, $pass, [switch]$Gibberish) {
    try {
        $fs = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    } catch {
        return @{ Status = "Error"; Message = "Cannot open file: $($_.Exception.Message)"; NewPath = $filePath }
    }

    $fname = [System.IO.Path]::GetFileName($filePath)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        if ($fs.Length -lt 1) {
            return @{ Status = "Skipped"; Message = "File is empty (0 bytes)"; NewPath = $filePath }
        }

        $finfo = Read-FileFooter $fs
        if ($finfo -and $finfo.Version -ne "Damaged") {
            if ($finfo.Version -eq 5 -and $finfo.Length -eq $FOOTER_LEN_V5_RESUMABLE) {
                $checkpoint = [BitConverter]::ToUInt64($finfo.Footer, 92)
                $state = [BitConverter]::ToUInt16($finfo.Footer, 102)
                if (($state -band 3) -eq $STATE_LOCK_IN_PROGRESS) {
                    # Resume interrupted lock forward
                    $salt = New-Object byte[] 16
                    [Array]::Copy($finfo.Footer, 12, $salt, 0, 16)
                    $nonce = New-Object byte[] 16
                    [Array]::Copy($finfo.Footer, 28, $nonce, 0, 16)
                    $crypto = Get-KeysV5 $pass $salt

                    $dataLen = $fs.Length - $FOOTER_LEN_V5_RESUMABLE
                    $aesEcb = [System.Security.Cryptography.Aes]::Create()
                    $aesEcb.Mode = [System.Security.Cryptography.CipherMode]::ECB
                    $aesEcb.Padding = [System.Security.Cryptography.PaddingMode]::None
                    $aesEcb.Key = $crypto.EncKey
                    $encryptor = $aesEcb.CreateEncryptor()

                    $pos = [long]$checkpoint
                    $blockIdx = [long]($pos / $CHUNK_SIZE_V5)
                    $lastSyncPos = $pos

                    while ($pos -lt $dataLen) {
                        $take = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($dataLen - $pos))
                        $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                        $buffer = New-Object byte[] $take
                        $read = $fs.Read($buffer, 0, $take)

                        [VaultFastCtr]::ProcessChunk($encryptor, $nonce, $buffer, 0, $take, ($blockIdx * 4096))

                        $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                        $fs.Write($buffer, 0, $take)

                        $pos += $take
                        $blockIdx++

                        # Physical Flash Write Barrier: Sync data to disk before advancing checkpoint
                        if (($pos - $lastSyncPos -ge (1024 * 1024)) -or ($pos -eq $dataLen)) {
                            Sync-FileToDisk $fs
                            $fs.Seek($dataLen + 92, [System.IO.SeekOrigin]::Begin) | Out-Null
                            $chkBytes = [BitConverter]::GetBytes([uint64]$pos)
                            $fs.Write($chkBytes, 0, 8)
                            Sync-FileToDisk $fs
                            $lastSyncPos = $pos
                        }

                        Render-Progress $fname $pos $dataLen $sw
                    }

                    # Compute final master MAC
                    $hmac = [System.Security.Cryptography.HMACSHA256]::new($crypto.MacKey)
                    $p = 0L
                    while ($p -lt $dataLen) {
                        $t = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($dataLen - $p))
                        $fs.Seek($p, [System.IO.SeekOrigin]::Begin) | Out-Null
                        $b = New-Object byte[] $t
                        $fs.Read($b, 0, $t) | Out-Null
                        if ($p + $t -eq $dataLen) { $hmac.TransformFinalBlock($b, 0, $t) | Out-Null }
                        else { $hmac.TransformBlock($b, 0, $t, $b, 0) | Out-Null }
                        $p += $t
                    }
                    $masterMac = $hmac.Hash

                    $fs.Seek($dataLen + 44, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $fs.Write($masterMac, 0, 32)
                    $fs.Seek($dataLen + 92, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $chkDone = [BitConverter]::GetBytes([uint64]$dataLen)
                    $fail0 = [BitConverter]::GetBytes([uint16]0)
                    $mode0 = [BitConverter]::GetBytes([uint16]$STATE_NORMAL_LOCKED)
                    $fs.Write($chkDone, 0, 8)
                    $fs.Write($fail0, 0, 2)
                    $fs.Write($mode0, 0, 2)
                    Sync-FileToDisk $fs

                    if ($fs.Length -ge (5 * 1024 * 1024)) { Write-Host "" }
                    return @{ Status = "Success"; Message = "Resumed & Finalized 100% Full-File AEAD ($dataLen bytes)"; NewPath = $filePath }
                }
            }
            return @{ Status = "Skipped"; Message = "Already locked"; NewPath = $filePath }
        }

        $dataLen = $fs.Length
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $salt = New-Object byte[] 16
        $nonce = New-Object byte[] 16
        $rng.GetBytes($salt)
        $rng.GetBytes($nonce)

        $crypto = Get-KeysV5 $pass $salt

        $aesEcb = [System.Security.Cryptography.Aes]::Create()
        $aesEcb.Mode = [System.Security.Cryptography.CipherMode]::ECB
        $aesEcb.Padding = [System.Security.Cryptography.PaddingMode]::None
        $aesEcb.Key = $crypto.EncKey
        $encryptor = $aesEcb.CreateEncryptor()

        $metaLen = 0L
        $metaBytes = $null
        if ($Gibberish) {
            $nameBytes = [System.Text.Encoding]::UTF8.GetBytes($fname)
            $nameLen = [uint16]$nameBytes.Length
            $metaLen = [long](2 + $nameBytes.Length)
            $metaBytes = New-Object byte[] $metaLen
            [BitConverter]::GetBytes($nameLen).CopyTo($metaBytes, 0)

            $nameCipher = New-Object byte[] $nameBytes.Length
            [Array]::Copy($nameBytes, 0, $nameCipher, 0, $nameBytes.Length)
            $startBlockIdx = [long]([Math]::Ceiling($dataLen / 16.0))
            [VaultFastCtr]::ProcessChunk($encryptor, $nonce, $nameCipher, 0, $nameCipher.Length, $startBlockIdx)
            [Array]::Copy($nameCipher, 0, $metaBytes, 2, $nameCipher.Length)

            $fs.Seek($dataLen, [System.IO.SeekOrigin]::Begin) | Out-Null
            $fs.Write($metaBytes, 0, $metaBytes.Length)
        }

        # Write initial 104-byte header at EOF with STATE_LOCK_IN_PROGRESS atomically and fsync
        $fs.Seek($dataLen + $metaLen, [System.IO.SeekOrigin]::Begin) | Out-Null
        $chunkSizeNum = [BitConverter]::GetBytes([uint32]$CHUNK_SIZE_V5)
        $chk0 = [BitConverter]::GetBytes([uint64]0)
        $failBytes = [BitConverter]::GetBytes([uint16]0)
        $modeBytes = [BitConverter]::GetBytes([uint16]$STATE_LOCK_IN_PROGRESS)
        $tempMac = New-Object byte[] 32

        $fs.Write($MAGIC_V5, 0, 8)
        $fs.Write($chunkSizeNum, 0, 4)
        $fs.Write($salt, 0, 16)
        $fs.Write($nonce, 0, 16)
        $fs.Write($tempMac, 0, 32)
        $fs.Write($crypto.AuthTag, 0, 16)
        $fs.Write($chk0, 0, 8)
        $fs.Write($failBytes, 0, 2)
        $fs.Write($modeBytes, 0, 2)
        Sync-FileToDisk $fs

        $hmac = [System.Security.Cryptography.HMACSHA256]::new($crypto.MacKey)
        $pos = 0L
        $blockIdx = 0L
        $lastSyncPos = 0L

        while ($pos -lt $dataLen) {
            $take = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($dataLen - $pos))
            $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
            $buffer = New-Object byte[] $take
            $read = $fs.Read($buffer, 0, $take)

            [VaultFastCtr]::ProcessChunk($encryptor, $nonce, $buffer, 0, $take, ($blockIdx * 4096))

            if (-not $Gibberish -and ($pos + $take -eq $dataLen)) {
                $hmac.TransformFinalBlock($buffer, 0, $take) | Out-Null
            } else {
                $hmac.TransformBlock($buffer, 0, $take, $buffer, 0) | Out-Null
            }

            $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
            $fs.Write($buffer, 0, $take)

            $pos += $take
            $blockIdx++

            # Physical Flash Write Barrier: Sync data to disk before advancing checkpoint
            if (($pos - $lastSyncPos -ge (1024 * 1024)) -or ($pos -eq $dataLen)) {
                Sync-FileToDisk $fs
                $fs.Seek($dataLen + $metaLen + 92, [System.IO.SeekOrigin]::Begin) | Out-Null
                $chkBytes = [BitConverter]::GetBytes([uint64]$pos)
                $fs.Write($chkBytes, 0, 8)
                Sync-FileToDisk $fs
                $lastSyncPos = $pos
            }

            Render-Progress $fname $pos $dataLen $sw
        }

        if ($Gibberish) {
            $hmac.TransformFinalBlock($metaBytes, 0, $metaBytes.Length) | Out-Null
        }

        $masterMac = $hmac.Hash

        $fs.Seek($dataLen + $metaLen + 44, [System.IO.SeekOrigin]::Begin) | Out-Null
        $fs.Write($masterMac, 0, 32)
        $fs.Seek($dataLen + $metaLen + 92, [System.IO.SeekOrigin]::Begin) | Out-Null
        $chkDone = [BitConverter]::GetBytes([uint64]$dataLen)
        $gibFlag = if ($Gibberish) { $FLAG_GIBBERISH_NAME } else { 0 }
        $finalModeVal = [uint16]($STATE_NORMAL_LOCKED -bor $gibFlag)
        $mode0 = [BitConverter]::GetBytes($finalModeVal)
        $fs.Write($chkDone, 0, 8)
        $fs.Write($failBytes, 0, 2)
        $fs.Write($mode0, 0, 2)
        Sync-FileToDisk $fs
        $fs.Close()

        if ($dataLen -ge (5 * 1024 * 1024)) { Write-Host "" }

        if ($Gibberish) {
            $randBytes = New-Object byte[] 8
            $rng.GetBytes($randBytes)
            $hexStr = ([BitConverter]::ToString($randBytes) -replace "-", "").ToLower()
            $gibberishName = "$hexStr.vault"
            $newPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($filePath), $gibberishName)
            try {
                [System.IO.File]::Move($filePath, $newPath)
                return @{ Status = "Success"; Message = "100% Full-File Resumable AEAD (Gibberish: $gibberishName)"; NewPath = $newPath }
            } catch {
                return @{ Status = "Success"; Message = "100% Full-File Resumable AEAD (Rename failed: $($_.Exception.Message))"; NewPath = $filePath }
            }
        }

        return @{ Status = "Success"; Message = "100% Full-File Resumable AEAD ($dataLen bytes, 600k PBKDF2)"; NewPath = $filePath }
    } finally {
        if ($fs) { $fs.Close() }
    }
}

function Unlock-FileV5($filePath, $pass) {
    try {
        $fs = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    } catch {
        return @{ Status = "Error"; Message = "Cannot open file: $($_.Exception.Message)"; NewPath = $filePath }
    }

    $fname = [System.IO.Path]::GetFileName($filePath)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $finfo = Read-FileFooter $fs
        if (-not $finfo) {
            return @{ Status = "Skipped"; Message = "Not locked"; NewPath = $filePath }
        }

        $footer = $finfo.Footer

        $checkpoint = [uint64]0
        $fails = 0
        $state = $STATE_NORMAL_LOCKED

        if ($finfo.Length -eq $FOOTER_LEN_V5_RESUMABLE) {
            $checkpoint = [BitConverter]::ToUInt64($footer, 92)
            $fails = [BitConverter]::ToUInt16($footer, 100)
            $state = [BitConverter]::ToUInt16($footer, 102)
        } else {
            $fails = [BitConverter]::ToUInt16($footer, 92)
            $state = [BitConverter]::ToUInt16($footer, 94)
        }

        $hasGibberish = ($state -band $FLAG_GIBBERISH_NAME) -ne 0
        $totalCipherLen = $fs.Length - $finfo.Length
        $dataLen = if ($hasGibberish) { [long]$checkpoint } else { $totalCipherLen }

        if ($finfo.Version -eq 5) {
            $salt = New-Object byte[] 16
            [Array]::Copy($footer, 12, $salt, 0, 16)
            $nonce = New-Object byte[] 16
            [Array]::Copy($footer, 28, $nonce, 0, 16)
            $storedMac = New-Object byte[] 32
            [Array]::Copy($footer, 44, $storedMac, 0, 32)
            $storedAuthTag = New-Object byte[] 16
            [Array]::Copy($footer, 76, $storedAuthTag, 0, 16)

            if ($fails -ge 10) {
                return @{ Status = "AuthFailed"; Message = "BRUTE-FORCE LOCKOUT ($fails failed attempts). Cooldown required."; NewPath = $filePath }
            }

            $crypto = Get-KeysV5 $pass $salt
            $computedAuthTag = $crypto.AuthTag

            # Constant-time tag check
            $match = $true
            for ($i = 0; $i -lt 16; $i++) {
                if ($storedAuthTag[$i] -ne $computedAuthTag[$i]) { $match = $false }
            }

            if (-not $match) {
                $fails++
                $fs.Seek(-4, [System.IO.SeekOrigin]::End) | Out-Null
                $failBytes = [BitConverter]::GetBytes([uint16]$fails)
                $fs.Write($failBytes, 0, 2)
                Sync-FileToDisk $fs
                $rem = [Math]::Max(0, 10 - $fails)
                return @{ Status = "AuthFailed"; Message = "INCORRECT PASSWORD ($fails failed attempts, $rem remaining before lockout)"; NewPath = $filePath }
            }

            $aesEcb = [System.Security.Cryptography.Aes]::Create()
            $aesEcb.Mode = [System.Security.Cryptography.CipherMode]::ECB
            $aesEcb.Padding = [System.Security.Cryptography.PaddingMode]::None
            $aesEcb.Key = $crypto.EncKey
            $encryptor = $aesEcb.CreateEncryptor()

            # CASE 1: Rollback an interrupted LOCK operation (User wants to decrypt partially locked file)
            if (($state -band 3) -eq $STATE_LOCK_IN_PROGRESS -and $checkpoint -gt 0) {
                $rollbackLen = [long][Math]::Min($checkpoint, [uint64]$dataLen)
                $pos = 0L
                $blockIdx = 0L
                while ($pos -lt $rollbackLen) {
                    $take = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($rollbackLen - $pos))
                    $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $buffer = New-Object byte[] $take
                    $read = $fs.Read($buffer, 0, $take)

                    [VaultFastCtr]::ProcessChunk($encryptor, $nonce, $buffer, 0, $take, ($blockIdx * 4096))

                    $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $fs.Write($buffer, 0, $take)

                    $pos += $take
                    $blockIdx++
                    Render-Progress $fname $pos $rollbackLen $sw
                }

                Sync-FileToDisk $fs
                $fs.SetLength($dataLen)
                Sync-FileToDisk $fs
                $fs.Close()
                if ($dataLen -ge (5 * 1024 * 1024)) { Write-Host "" }
                return @{ Status = "Success"; Message = "Rolled Back Interrupted Lock & Fully Restored Original ($dataLen bytes)"; NewPath = $filePath }
            }

            # CASE 2: Resume an interrupted UNLOCK operation
            $startPos = 0L
            if (($state -band 3) -eq $STATE_UNLOCK_IN_PROGRESS -and $checkpoint -gt 0) {
                $startPos = [long]$checkpoint
            } else {
                # Authenticate Ciphertext (Anti-Tampering Integrity Check)
                $hmac = [System.Security.Cryptography.HMACSHA256]::new($crypto.MacKey)
                $p = 0L
                while ($p -lt $totalCipherLen) {
                    $t = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($totalCipherLen - $p))
                    $fs.Seek($p, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $b = New-Object byte[] $t
                    $fs.Read($b, 0, $t) | Out-Null
                    if ($p + $t -eq $totalCipherLen) { $hmac.TransformFinalBlock($b, 0, $t) | Out-Null }
                    else { $hmac.TransformBlock($b, 0, $t, $b, 0) | Out-Null }
                    $p += $t
                }

                $computedMac = $hmac.Hash
                $macMatch = $true
                for ($i = 0; $i -lt 32; $i++) {
                    if ($storedMac[$i] -ne $computedMac[$i]) { $macMatch = $false }
                }

                if (-not $macMatch) {
                    return @{ Status = "Error"; Message = "INTEGRITY ERROR: Ciphertext has been modified or corrupted! Decryption halted."; NewPath = $filePath }
                }

                if ($finfo.Length -eq $FOOTER_LEN_V5_RESUMABLE) {
                    $fs.Seek($totalCipherLen + 92, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $chk0 = [BitConverter]::GetBytes([uint64]0)
                    $failBytes = [BitConverter]::GetBytes([uint16]$fails)
                    $gibFlag = if ($hasGibberish) { $FLAG_GIBBERISH_NAME } else { 0 }
                    $modeUnlockVal = [uint16]($STATE_UNLOCK_IN_PROGRESS -bor $gibFlag)
                    $modeUnlock = [BitConverter]::GetBytes($modeUnlockVal)
                    $fs.Write($chk0, 0, 8)
                    $fs.Write($failBytes, 0, 2)
                    $fs.Write($modeUnlock, 0, 2)
                    Sync-FileToDisk $fs
                }
            }

            $restoredOrigName = $null
            if ($hasGibberish) {
                $fs.Seek($dataLen, [System.IO.SeekOrigin]::Begin) | Out-Null
                $lenBuf = New-Object byte[] 2
                $readLen = $fs.Read($lenBuf, 0, 2)
                if ($readLen -eq 2) {
                    $nameLen = [BitConverter]::ToUInt16($lenBuf, 0)
                    if ($nameLen -gt 0 -and $nameLen -lt 2048) {
                        $encName = New-Object byte[] $nameLen
                        $fs.Read($encName, 0, $nameLen) | Out-Null
                        $startBlockIdx = [long]([Math]::Ceiling($dataLen / 16.0))
                        [VaultFastCtr]::ProcessChunk($encryptor, $nonce, $encName, 0, $encName.Length, $startBlockIdx)
                        try {
                            $restoredOrigName = [System.Text.Encoding]::UTF8.GetString($encName)
                        } catch {
                            $restoredOrigName = $null
                        }
                    }
                }
            }

            # Decrypt in-place stream via C# accelerator
            $pos = $startPos
            $blockIdx = [long]($pos / $CHUNK_SIZE_V5)
            $lastSyncPos = $pos

            while ($pos -lt $dataLen) {
                $take = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($dataLen - $pos))
                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $buffer = New-Object byte[] $take
                $read = $fs.Read($buffer, 0, $take)

                [VaultFastCtr]::ProcessChunk($encryptor, $nonce, $buffer, 0, $take, ($blockIdx * 4096))

                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $fs.Write($buffer, 0, $take)

                $pos += $take
                $blockIdx++

                # Physical Flash Write Barrier: Sync data to disk before advancing checkpoint
                if ($finfo.Length -eq $FOOTER_LEN_V5_RESUMABLE) {
                    if (($pos - $lastSyncPos -ge (1024 * 1024)) -or ($pos -eq $dataLen)) {
                        Sync-FileToDisk $fs
                        $fs.Seek($totalCipherLen + 92, [System.IO.SeekOrigin]::Begin) | Out-Null
                        $chkBytes = [BitConverter]::GetBytes([uint64]$pos)
                        $fs.Write($chkBytes, 0, 8)
                        Sync-FileToDisk $fs
                        $lastSyncPos = $pos
                    }
                }

                Render-Progress $fname $pos $dataLen $sw
            }

            Sync-FileToDisk $fs
            $fs.SetLength($dataLen)
            Sync-FileToDisk $fs
            $fs.Close()

            if ($dataLen -ge (5 * 1024 * 1024)) { Write-Host "" }

            if ($hasGibberish -and $restoredOrigName) {
                $dirName = [System.IO.Path]::GetDirectoryName($filePath)
                $restoredPath = [System.IO.Path]::Combine($dirName, $restoredOrigName)
                if ((Test-Path -LiteralPath $restoredPath) -and $restoredPath -ne $filePath) {
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($restoredOrigName)
                    $ext = [System.IO.Path]::GetExtension($restoredOrigName)
                    $restoredPath = [System.IO.Path]::Combine($dirName, "${baseName}_restored${ext}")
                }
                try {
                    [System.IO.File]::Move($filePath, $restoredPath)
                    return @{ Status = "Success"; Message = "Verified & Restored original file $([System.IO.Path]::GetFileName($restoredPath)) ($dataLen bytes)"; NewPath = $restoredPath }
                } catch {
                    return @{ Status = "Success"; Message = "Verified & Restored ($dataLen bytes), rename failed: $($_.Exception.Message)"; NewPath = $filePath }
                }
            }

            if ($startPos -gt 0) {
                return @{ Status = "Success"; Message = "Resumed & Fully Restored ($dataLen bytes, resumed from $([Math]::Round($startPos/1MB, 2)) MB)"; NewPath = $filePath }
            }
            return @{ Status = "Success"; Message = "Verified & Restored 100% full file ($dataLen bytes)"; NewPath = $filePath }

        } else {
            return @{ Status = "Error"; Message = "Legacy format detected. Please use Python tools/vault.py unlock."; NewPath = $filePath }
        }
    } finally {
        if ($fs) { $fs.Close() }
    }
}

# Clean input path
$cleanPath = $Path.Trim().Trim('"').Trim("'")
if (Test-Path -LiteralPath $cleanPath) {
    $resolvedPath = (Get-Item -LiteralPath $cleanPath).FullName
} else {
    Write-Host "Target path does not exist: $cleanPath" -ForegroundColor Red
    exit 1
}

function Get-SafeTargetFiles([string]$rootPath) {
    $results = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($rootPath)

    while ($stack.Count -gt 0) {
        $currentDir = $stack.Pop()
        try {
            $di = New-Object System.IO.DirectoryInfo($currentDir)
            if ($currentDir -ne $rootPath -and $di.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
                continue
            }

            foreach ($subDir in $di.GetDirectories()) {
                $subName = $subDir.Name.ToLower()
                if ($subDir.Name.StartsWith(".") -or 
                    $subName -eq "tools" -or 
                    $subName -eq ".vault" -or 
                    $subName -eq "__pycache__" -or 
                    $subName -eq ".git" -or 
                    $subName -eq "node_modules" -or
                    $subName -eq "bin" -or
                    $subName -eq "cmd" -or
                    $subName -eq "installers" -or
                    $subName -eq "android" -or
                    $subName.StartsWith("releases") -or
                    $subDir.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
                    continue
                }
                $stack.Push($subDir.FullName)
            }

            foreach ($file in $di.GetFiles()) {
                $ext = $file.Extension.ToLower()
                if ($file.Name.StartsWith(".") -or 
                    $file.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) -or
                    $ext -eq ".bat" -or $ext -eq ".ps1" -or $ext -eq ".cmd" -or 
                    $ext -eq ".py" -or $ext -eq ".sh" -or $ext -eq ".html" -or 
                    $ext -eq ".git" -or $ext -eq ".gitignore" -or $ext -eq ".env" -or $ext -eq ".log") {
                    continue
                }
                $results.Add($file)
            }
        } catch {
            # Skip any inaccessible folders
        }
    }
    return $results.ToArray()
}

$targetFiles = @()
if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
    $item = Get-Item -LiteralPath $resolvedPath
    if (-not $item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
        $targetFiles = @($item)
    }
} else {
    $targetFiles = Get-SafeTargetFiles $resolvedPath
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  Universal Vault v5.5.4 (Enterprise Grade): $Action Operation" -ForegroundColor Cyan
Write-Host "  Target Scope: $resolvedPath" -ForegroundColor Cyan
Write-Host "  Files Identified: $($targetFiles.Count)" -ForegroundColor Cyan
if ($Action -eq "Lock") {
    Write-Host "  Armor Mode: 100% Full-File Resumable AEAD (Stream Encrypt-then-MAC)" -ForegroundColor Cyan
    Write-Host "  Security: 600,000 PBKDF2-SHA256 Rounds | Anti-Tampering HMAC-SHA256" -ForegroundColor Cyan
    Write-Host "  Fault Tolerance: Checkpointed In-Place Streaming (Crash-Safe Resumable)" -ForegroundColor Cyan
    if ($Gibberish) {
        Write-Host "  Gibberish Naming: ENABLED (Files renamed to randomized 16-hex hashes)" -ForegroundColor Cyan
    }
}
Write-Host "======================================================================" -ForegroundColor Cyan

if ($Action -eq "Status") {
    $locked = 0
    $unlocked = 0
    foreach ($file in $targetFiles) {
        $rel = $file.FullName
        $st = Check-FileLockStatus $file.FullName
        if ($st.StartsWith("locked")) {
            Write-Host "  [LOCKED]   $rel ($st)" -ForegroundColor Red
            $locked++
        } else {
            Write-Host "  [UNLOCKED] $rel" -ForegroundColor Green
            $unlocked++
        }
    }
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Summary: $locked Locked | $unlocked Unlocked`n" -ForegroundColor Cyan
    exit 0
}

if ([string]::IsNullOrEmpty($Password)) {
    $secPass = Read-Host -Prompt "Enter Master Password to $Action" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPass)
    $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}

if ([string]::IsNullOrEmpty($Password)) {
    Write-Host "Password cannot be empty." -ForegroundColor Red
    exit 1
}

$successCount = 0
$failCount = 0
$skipCount = 0

foreach ($file in $targetFiles) {
    $rel = $file.Name
    Write-Host "Processing: $rel... "
    if ($Action -eq "Lock") {
        $res = Lock-FileV5 $file.FullName $Password -Gibberish:$Gibberish
    } else {
        $res = Unlock-FileV5 $file.FullName $Password
    }

    if ($res.Status -eq "Success") {
        $arrow = ""
        if ($res.NewPath -and ($res.NewPath -ne $file.FullName)) {
            $arrow = " -> $([System.IO.Path]::GetFileName($res.NewPath))"
        }
        Write-Host "  [SUCCESS$($arrow): $($res.Message)]" -ForegroundColor Green
        $successCount++
    } elseif ($res.Status -eq "Skipped") {
        Write-Host "  [SKIPPED: $($res.Message)]" -ForegroundColor Yellow
        $skipCount++
    } elseif ($res.Status -eq "AuthFailed") {
        Write-Host "  [FAILED: $($res.Message)]" -ForegroundColor Red
        $failCount++
    } else {
        Write-Host "  [FAILED: $($res.Message)]" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "Summary: $successCount Succeeded | $skipCount Skipped | $failCount Failed" -ForegroundColor Cyan
