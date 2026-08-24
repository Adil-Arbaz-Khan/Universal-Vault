# Universal Vault V5 (Enterprise Grade) PowerShell Engine
# Authenticated In-Place Stream Encryption (AES-256-CTR + HMAC-SHA256)
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("Lock", "Unlock", "Status")]
    [string]$Action = "Status",

    [Parameter(Position=1)]
    [string]$Path = ".",

    [Parameter(Position=2)]
    [string]$Password
)

$MAGIC_V5 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV05")
$MAGIC_V4 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV04")
$MAGIC_V3 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV03")
$MAGIC_V2 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV02")
$MAGIC_V1 = [System.Text.Encoding]::ASCII.GetBytes("HDRLOK01")

$FOOTER_LEN_V5 = 96
$FOOTER_LEN_V4 = 80
$FOOTER_LEN_V3 = 80
$FOOTER_LEN_V2 = 76

$CHUNK_SIZE_V5 = 65536  # 64 KB streaming chunks
$KDF_ITERS_V5 = 600000  # OWASP 2026 Gold Standard (600,000 rounds)

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

function Process-AesCtrChunk($aesEcbEncryptor, $nonce, $chunkBytes, [long]$startBlockIndex) {
    $len = $chunkBytes.Length
    $out = New-Object byte[] $len
    $blocks = [Math]::Ceiling($len / 16.0)

    $counterInt = 0L
    # Big-endian nonce calculation
    $nonceCopy = New-Object byte[] 16
    [Array]::Copy($nonce, 0, $nonceCopy, 0, 16)

    $keystreamBlock = New-Object byte[] 16
    $curCounterBlock = New-Object byte[] 16

    for ($b = 0; $b -lt $blocks; $b++) {
        $curIdx = $startBlockIndex + $b
        [Array]::Copy($nonceCopy, 0, $curCounterBlock, 0, 16)

        # Add 64-bit block counter to last 8 bytes in big-endian
        $low = [BitConverter]::ToUInt64($nonceCopy, 8)
        if ([BitConverter]::IsLittleEndian) {
            $bytes = [BitConverter]::GetBytes($low)
            [Array]::Reverse($bytes)
            $low = [BitConverter]::ToUInt64($bytes, 0)
        }
        $newLow = $low + [uint64]$curIdx
        $newLowBytes = [BitConverter]::GetBytes($newLow)
        if ([BitConverter]::IsLittleEndian) {
            [Array]::Reverse($newLowBytes)
        }
        [Array]::Copy($newLowBytes, 0, $curCounterBlock, 8, 8)

        $aesEcbEncryptor.TransformBlock($curCounterBlock, 0, 16, $keystreamBlock, 0) | Out-Null

        $offset = $b * 16
        $take = [Math]::Min(16, $len - $offset)
        for ($i = 0; $i -lt $take; $i++) {
            $out[$offset + $i] = $chunkBytes[$offset + $i] -bxor $keystreamBlock[$i]
        }
    }
    return $out
}

function Read-FileFooter($fs) {
    if ($fs.Length -ge $FOOTER_LEN_V5) {
        $fs.Seek(-$FOOTER_LEN_V5, [System.IO.SeekOrigin]::End) | Out-Null
        $chk = New-Object byte[] 8
        $fs.Read($chk, 0, 8) | Out-Null
        if ([System.Text.Encoding]::ASCII.GetString($chk) -eq "VAULTV05") {
            $fs.Seek(-$FOOTER_LEN_V5, [System.IO.SeekOrigin]::End) | Out-Null
            $buf = New-Object byte[] $FOOTER_LEN_V5
            $fs.Read($buf, 0, $FOOTER_LEN_V5) | Out-Null
            return @{ Version = 5; Footer = $buf; Length = $FOOTER_LEN_V5 }
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
                if ($finfo.Version -eq 5) {
                    $fails = [BitConverter]::ToUInt16($finfo.Footer, 92)
                    $lbl = "V5 Authenticated AEAD (100% Full-File)"
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

function Lock-FileV5($filePath, $pass) {
    try {
        $fs = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    } catch {
        return @{ Status = "Error"; Message = "Cannot open file: $($_.Exception.Message)" }
    }

    try {
        if ($fs.Length -lt 1) {
            return @{ Status = "Skipped"; Message = "File is empty (0 bytes)" }
        }

        $finfo = Read-FileFooter $fs
        if ($finfo) {
            return @{ Status = "Skipped"; Message = "Already locked" }
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

        $hmac = [System.Security.Cryptography.HMACSHA256]::new($crypto.MacKey)

        $pos = 0L
        $blockIdx = 0L

        while ($pos -lt $dataLen) {
            $take = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($dataLen - $pos))
            $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
            $buffer = New-Object byte[] $take
            $read = $fs.Read($buffer, 0, $take)

            $cipherChunk = Process-AesCtrChunk $encryptor $nonce $buffer ($blockIdx * 4096)

            # Update HMAC over ciphertext
            if ($pos + $take -eq $dataLen) {
                $hmac.TransformFinalBlock($cipherChunk, 0, $take) | Out-Null
            } else {
                $hmac.TransformBlock($cipherChunk, 0, $take, $cipherChunk, 0) | Out-Null
            }

            $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
            $fs.Write($cipherChunk, 0, $take)

            $pos += $take
            $blockIdx++
        }

        $masterMac = $hmac.Hash

        $fs.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
        $chunkSizeNum = [BitConverter]::GetBytes([uint32]$CHUNK_SIZE_V5)
        $failBytes = [BitConverter]::GetBytes([uint16]0)
        $modeBytes = [BitConverter]::GetBytes([uint16]1)

        $fs.Write($MAGIC_V5, 0, 8)
        $fs.Write($chunkSizeNum, 0, 4)
        $fs.Write($salt, 0, 16)
        $fs.Write($nonce, 0, 16)
        $fs.Write($masterMac, 0, 32)
        $fs.Write($crypto.AuthTag, 0, 16)
        $fs.Write($failBytes, 0, 2)
        $fs.Write($modeBytes, 0, 2)
        $fs.Flush()

        return @{ Status = "Success"; Message = "100% Full-File AEAD ($dataLen bytes, Authenticated EtM + 600k PBKDF2)" }
    } finally {
        $fs.Close()
    }
}

function Unlock-FileV5($filePath, $pass) {
    try {
        $fs = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    } catch {
        return @{ Status = "Error"; Message = "Cannot open file: $($_.Exception.Message)" }
    }

    try {
        $finfo = Read-FileFooter $fs
        if (-not $finfo) {
            return @{ Status = "Skipped"; Message = "Not locked" }
        }

        $footer = $finfo.Footer
        $dataLen = $fs.Length - $finfo.Length

        if ($finfo.Version -eq 5) {
            $salt = New-Object byte[] 16
            [Array]::Copy($footer, 12, $salt, 0, 16)
            $nonce = New-Object byte[] 16
            [Array]::Copy($footer, 28, $nonce, 0, 16)
            $storedMac = New-Object byte[] 32
            [Array]::Copy($footer, 44, $storedMac, 0, 32)
            $storedAuthTag = New-Object byte[] 16
            [Array]::Copy($footer, 76, $storedAuthTag, 0, 16)
            $fails = [BitConverter]::ToUInt16($footer, 92)

            if ($fails -ge 10) {
                return @{ Status = "AuthFailed"; Message = "BRUTE-FORCE LOCKOUT ($fails failed attempts). Cooldown required." }
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
                $fs.Flush()
                $rem = [Math]::Max(0, 10 - $fails)
                return @{ Status = "AuthFailed"; Message = "INCORRECT PASSWORD ($fails failed attempts, $rem remaining before lockout)" }
            }

            # Authenticate Ciphertext (Anti-Tampering Integrity Check)
            $hmac = [System.Security.Cryptography.HMACSHA256]::new($crypto.MacKey)
            $pos = 0L
            while ($pos -lt $dataLen) {
                $take = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($dataLen - $pos))
                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $buffer = New-Object byte[] $take
                $read = $fs.Read($buffer, 0, $take)
                if ($pos + $take -eq $dataLen) {
                    $hmac.TransformFinalBlock($buffer, 0, $take) | Out-Null
                } else {
                    $hmac.TransformBlock($buffer, 0, $take, $buffer, 0) | Out-Null
                }
                $pos += $take
            }

            $computedMac = $hmac.Hash
            $macMatch = $true
            for ($i = 0; $i -lt 32; $i++) {
                if ($storedMac[$i] -ne $computedMac[$i]) { $macMatch = $false }
            }

            if (-not $macMatch) {
                return @{ Status = "Error"; Message = "INTEGRITY ERROR: Ciphertext has been modified or corrupted! Decryption halted." }
            }

            # Decrypt in-place stream
            $aesEcb = [System.Security.Cryptography.Aes]::Create()
            $aesEcb.Mode = [System.Security.Cryptography.CipherMode]::ECB
            $aesEcb.Padding = [System.Security.Cryptography.PaddingMode]::None
            $aesEcb.Key = $crypto.EncKey
            $encryptor = $aesEcb.CreateEncryptor()

            $pos = 0L
            $blockIdx = 0L
            while ($pos -lt $dataLen) {
                $take = [int][Math]::Min([long]$CHUNK_SIZE_V5, ($dataLen - $pos))
                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $buffer = New-Object byte[] $take
                $read = $fs.Read($buffer, 0, $take)

                $plainChunk = Process-AesCtrChunk $encryptor $nonce $buffer ($blockIdx * 4096)

                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $fs.Write($plainChunk, 0, $take)

                $pos += $take
                $blockIdx++
            }

            $fs.SetLength($dataLen)
            $fs.Flush()
            return @{ Status = "Success"; Message = "Verified & Restored 100% full file ($dataLen bytes)" }

        } else {
            # Legacy Decryption fallback
            return @{ Status = "Error"; Message = "Legacy format detected. Please use Python tools/vault.py unlock." }
        }
    } finally {
        $fs.Close()
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
Write-Host "  Universal Vault V5 (Enterprise Grade): $Action Operation" -ForegroundColor Cyan
Write-Host "  Target Scope: $resolvedPath" -ForegroundColor Cyan
Write-Host "  Files Identified: $($targetFiles.Count)" -ForegroundColor Cyan
if ($Action -eq "Lock") {
    Write-Host "  Armor Mode: 100% Full-File AEAD (Stream Encrypt-then-MAC)" -ForegroundColor Cyan
    Write-Host "  Security: 600,000 PBKDF2-SHA256 Rounds | Anti-Tampering HMAC-SHA256" -ForegroundColor Cyan
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
    Write-Host -NoNewline "Processing: $rel... "
    if ($Action -eq "Lock") {
        $res = Lock-FileV5 $file.FullName $Password
    } else {
        $res = Unlock-FileV5 $file.FullName $Password
    }

    if ($res.Status -eq "Success") {
        Write-Host "[$($res.Status)]" -ForegroundColor Green
        $successCount++
    } elseif ($res.Status -eq "Skipped") {
        Write-Host "[$($res.Status): $($res.Message)]" -ForegroundColor Yellow
        $skipCount++
    } elseif ($res.Status -eq "AuthFailed") {
        Write-Host "[$($res.Message)]" -ForegroundColor Red
        $failCount++
    } else {
        Write-Host "[$($res.Status): $($res.Message)]" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "Summary: $successCount Succeeded | $skipCount Skipped | $failCount Failed" -ForegroundColor Cyan
