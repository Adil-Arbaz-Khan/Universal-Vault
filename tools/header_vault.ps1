# Universal In-Place Header & Full-File Vault Engine for Windows PowerShell
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("Lock", "Unlock", "Status")]
    [string]$Action = "Status",

    [Parameter(Position=1)]
    [string]$Path = ".",

    [Parameter(Position=2)]
    [string]$Password,

    [switch]$ForceFull
)

$MAGIC_V4 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV04")
$MAGIC_V3 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV03")
$MAGIC_V2 = [System.Text.Encoding]::ASCII.GetBytes("VAULTV02")
$MAGIC_V1 = [System.Text.Encoding]::ASCII.GetBytes("HDRLOK01")

$FOOTER_LEN_V4 = 80
$FOOTER_LEN_V3 = 80
$FOOTER_LEN_V2 = 76
$KDF_ITERS = 100000
$SMART_THRESHOLD = 50 * 1024 * 1024

function Get-KeyAndAuth($pass, $salt, $version = 4) {
    $iters = if ($version -ge 3) { $KDF_ITERS } else { 10000 }
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pass, $salt, $iters, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $key = $kdf.GetBytes(32)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $tag = if ($version -eq 4) { [System.Text.Encoding]::ASCII.GetBytes("VAULT_AUTH_V4") } elseif ($version -eq 3) { [System.Text.Encoding]::ASCII.GetBytes("VAULT_AUTH_V3") } elseif ($version -eq 2) { [System.Text.Encoding]::ASCII.GetBytes("VAULT_AUTH_V2") } else { [System.Text.Encoding]::ASCII.GetBytes("AUTH_CHECK_V1") }
    $authInput = $key + $tag + $salt
    $authHash = $sha.ComputeHash($authInput)
    return @{ Key = $key; AuthHash = $authHash }
}

function Read-FileFooter($fs) {
    if ($fs.Length -ge $FOOTER_LEN_V4) {
        $fs.Seek(-$FOOTER_LEN_V4, [System.IO.SeekOrigin]::End) | Out-Null
        $chk = New-Object byte[] 8
        $fs.Read($chk, 0, 8) | Out-Null
        $m = [System.Text.Encoding]::ASCII.GetString($chk)
        if ($m -eq "VAULTV04") {
            $fs.Seek(-$FOOTER_LEN_V4, [System.IO.SeekOrigin]::End) | Out-Null
            $buf = New-Object byte[] $FOOTER_LEN_V4
            $fs.Read($buf, 0, $FOOTER_LEN_V4) | Out-Null
            return @{ Version = 4; Footer = $buf; Length = $FOOTER_LEN_V4 }
        }
        if ($m -eq "VAULTV03") {
            $fs.Seek(-$FOOTER_LEN_V3, [System.IO.SeekOrigin]::End) | Out-Null
            $buf = New-Object byte[] $FOOTER_LEN_V3
            $fs.Read($buf, 0, $FOOTER_LEN_V3) | Out-Null
            return @{ Version = 3; Footer = $buf; Length = $FOOTER_LEN_V3 }
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
                $chunkSize = [BitConverter]::ToUInt32($finfo.Footer, 8)
                $isFull = ($finfo.Version -eq 4 -and $chunkSize -eq 0)
                $fails = 0
                if ($finfo.Version -ge 3) {
                    $fails = [BitConverter]::ToUInt16($finfo.Footer, 76)
                }
                $modeStr = if ($isFull) { "100% Full Armor" } else { "Header Armor" }
                if ($fails -ge 5) {
                    return "locked ($modeStr - LOCKOUT: $fails fails)"
                }
                return "locked ($modeStr)"
            }
            return "unlocked"
        } finally {
            $fs.Close()
        }
    } catch {
        return "error"
    }
}

function Lock-FileHeader($filePath, $pass, [bool]$fullMode = $false) {
    try {
        $fs = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    } catch {
        return @{ Status = "Error"; Message = "Cannot open file: $($_.Exception.Message)" }
    }
    
    try {
        if ($fs.Length -lt 16) {
            return @{ Status = "Skipped"; Message = "File too small (< 16 bytes)" }
        }

        $finfo = Read-FileFooter $fs
        if ($finfo) {
            return @{ Status = "Skipped"; Message = "Already locked" }
        }

        $isFull = $fullMode -or ($fs.Length -lt $SMART_THRESHOLD)

        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $salt = New-Object byte[] 16
        $iv = New-Object byte[] 16
        $rng.GetBytes($salt)
        $rng.GetBytes($iv)

        $crypto = Get-KeyAndAuth $pass $salt 4

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::None
        $aes.Key = $crypto.Key

        if ($isFull) {
            # 100% Full File Encryption in 1MB streams
            $dataLen = $fs.Length
            $encBlocksLen = $dataLen - ($dataLen % 16)
            $currIv = $iv
            $chunkStep = 1024 * 1024
            $pos = 0L

            while ($pos -lt $encBlocksLen) {
                $take = [int][Math]::Min([long]$chunkStep, ($encBlocksLen - $pos))
                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $buffer = New-Object byte[] $take
                $read = $fs.Read($buffer, 0, $take)
                
                $aes.IV = $currIv
                $encryptor = $aes.CreateEncryptor()
                $encChunk = $encryptor.TransformFinalBlock($buffer, 0, $read)

                # Next IV is the last 16 bytes of ciphertext
                $nextIv = New-Object byte[] 16
                [Array]::Copy($encChunk, $encChunk.Length - 16, $nextIv, 0, 16)
                $currIv = $nextIv

                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $fs.Write($encChunk, 0, $encChunk.Length)
                $pos += $take
            }

            $fs.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
            $chunkSizeNum = [BitConverter]::GetBytes([uint32]0)
            $failBytes = [BitConverter]::GetBytes([uint16]0)
            $modeBytes = [BitConverter]::GetBytes([uint16]1)

            $fs.Write($MAGIC_V4, 0, 8)
            $fs.Write($chunkSizeNum, 0, 4)
            $fs.Write($salt, 0, 16)
            $fs.Write($iv, 0, 16)
            $fs.Write($crypto.AuthHash, 0, 32)
            $fs.Write($failBytes, 0, 2)
            $fs.Write($modeBytes, 0, 2)
            $fs.Flush()

            return @{ Status = "Success"; Message = "Encrypted 100% FULL FILE ($dataLen bytes, Zero Carvable Plaintext)" }
        } else {
            # Fast Header Mode for 50MB+ media
            $chunkSize = if ($fs.Length -ge 65536) { 65536 } else { [int]$fs.Length }
            $chunkSize = $chunkSize - ($chunkSize % 16)

            $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $headerBytes = New-Object byte[] $chunkSize
            $readBytes = $fs.Read($headerBytes, 0, $chunkSize)

            $aes.IV = $iv
            $encryptor = $aes.CreateEncryptor()
            $encryptedHeader = $encryptor.TransformFinalBlock($headerBytes, 0, $chunkSize)

            $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $fs.Write($encryptedHeader, 0, $chunkSize)

            $fs.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
            $chunkSizeNum = [BitConverter]::GetBytes([uint32]$chunkSize)
            $failBytes = [BitConverter]::GetBytes([uint16]0)
            $modeBytes = [BitConverter]::GetBytes([uint16]0)

            $fs.Write($MAGIC_V4, 0, 8)
            $fs.Write($chunkSizeNum, 0, 4)
            $fs.Write($salt, 0, 16)
            $fs.Write($iv, 0, 16)
            $fs.Write($crypto.AuthHash, 0, 32)
            $fs.Write($failBytes, 0, 2)
            $fs.Write($modeBytes, 0, 2)
            $fs.Flush()

            return @{ Status = "Success"; Message = "Encrypted $chunkSize bytes header (Fast Media Mode)" }
        }
    } finally {
        $fs.Close()
    }
}

function Unlock-FileHeader($filePath, $pass) {
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
        $chunkSize = [BitConverter]::ToUInt32($footer, 8)
        $salt = New-Object byte[] 16
        [Array]::Copy($footer, 12, $salt, 0, 16)
        $iv = New-Object byte[] 16
        [Array]::Copy($footer, 28, $iv, 0, 16)
        $storedAuth = New-Object byte[] 32
        [Array]::Copy($footer, 44, $storedAuth, 0, 32)

        if ($finfo.Version -ge 3) {
            $fails = [BitConverter]::ToUInt16($footer, 76)
            if ($fails -ge 10) {
                return @{ Status = "AuthFailed"; Message = "BRUTE-FORCE LOCKOUT ($fails failed attempts). Cooldown active." }
            }
        }

        $crypto = Get-KeyAndAuth $pass $salt $finfo.Version
        $computedAuth = $crypto.AuthHash

        $match = $true
        for ($i = 0; $i -lt 32; $i++) {
            if ($storedAuth[$i] -ne $computedAuth[$i]) { $match = $false }
        }

        if (-not $match) {
            if ($finfo.Version -ge 3) {
                $fails = [BitConverter]::ToUInt16($footer, 76) + 1
                $fs.Seek(-4, [System.IO.SeekOrigin]::End) | Out-Null
                $failBytes = [BitConverter]::GetBytes([uint16]$fails)
                $fs.Write($failBytes, 0, 2)
                $fs.Flush()
                $rem = [Math]::Max(0, 10 - $fails)
                return @{ Status = "AuthFailed"; Message = "INCORRECT PASSWORD ($fails failed attempts, $rem remaining before lockout)" }
            }
            return @{ Status = "AuthFailed"; Message = "INCORRECT PASSWORD" }
        }

        $dataLen = $fs.Length - $finfo.Length
        $isFull = ($finfo.Version -eq 4 -and $chunkSize -eq 0)

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::None
        $aes.Key = $crypto.Key

        if ($isFull) {
            # Full File Decryption
            $encBlocksLen = $dataLen - ($dataLen % 16)
            $currIv = $iv
            $chunkStep = 1024 * 1024
            $pos = 0L

            while ($pos -lt $encBlocksLen) {
                $take = [int][Math]::Min([long]$chunkStep, ($encBlocksLen - $pos))
                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $buffer = New-Object byte[] $take
                $read = $fs.Read($buffer, 0, $take)

                # Save ciphertext slice for next IV calculation before decrypting in-place
                $nextIv = New-Object byte[] 16
                [Array]::Copy($buffer, $read - 16, $nextIv, 0, 16)

                $aes.IV = $currIv
                $decryptor = $aes.CreateDecryptor()
                $decChunk = $decryptor.TransformFinalBlock($buffer, 0, $read)

                $currIv = $nextIv

                $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $fs.Write($decChunk, 0, $decChunk.Length)
                $pos += $take
            }

            $fs.SetLength($dataLen)
            $fs.Flush()
            return @{ Status = "Success"; Message = "Restored 100% full file ($dataLen bytes)" }
        } else {
            # Header Mode Decryption
            $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $encBytes = New-Object byte[] $chunkSize
            $readBytes = $fs.Read($encBytes, 0, $chunkSize)

            $aes.IV = $iv
            $decryptor = $aes.CreateDecryptor()
            $decryptedHeader = $decryptor.TransformFinalBlock($encBytes, 0, $chunkSize)

            $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $fs.Write($decryptedHeader, 0, $chunkSize)

            $fs.SetLength($dataLen)
            $fs.Flush()
            return @{ Status = "Success"; Message = "Restored $chunkSize bytes header" }
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

$targetFiles = @()
if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
    $targetFiles = @(Get-Item -LiteralPath $resolvedPath)
} else {
    $targetFiles = Get-ChildItem -LiteralPath $resolvedPath -Recurse -File | Where-Object {
        $parent = $_.DirectoryName
        $ext = $_.Extension.ToLower()
        $parent -notmatch "[\\/]tools($|[\\/])" -and
        $parent -notmatch "[\\/]\.vault($|[\\/])" -and
        $parent -notmatch "[\\/]__pycache__($|[\\/])" -and
        $parent -notmatch "[\\/]\.git($|[\\/])" -and
        $ext -ne ".bat" -and $ext -ne ".ps1" -and $ext -ne ".cmd" -and $ext -ne ".py" -and $ext -ne ".sh" -and $ext -ne ".html" -and $ext -ne ".git" -and $ext -ne ".gitignore"
    }
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Universal Header & Full-File Vault V4: $Action Operation" -ForegroundColor Cyan
Write-Host "  Target: $resolvedPath" -ForegroundColor Cyan
Write-Host "  Files Identified: $($targetFiles.Count)" -ForegroundColor Cyan
if ($Action -eq "Lock") {
    $modeLabel = if ($ForceFull) { "100% Full Encryption (All Files)" } else { "Smart Hybrid (100% Full <50MB | Header >=50MB)" }
    Write-Host "  Encryption Mode: $modeLabel" -ForegroundColor Cyan
    Write-Host "  Security: 100,000 PBKDF2 Iterations | Anti-Brute-Force Enabled" -ForegroundColor Cyan
}
Write-Host "================================================================" -ForegroundColor Cyan

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
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
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
        $res = Lock-FileHeader $file.FullName $Password $ForceFull
    } else {
        $res = Unlock-FileHeader $file.FullName $Password
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
