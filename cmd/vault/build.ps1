# Universal Vault CLI Cross-Platform Builder
[CmdletBinding()]
param()

$goExe = "go"
if (Test-Path "C:\Program Files\Go\bin\go.exe") {
    $goExe = "C:\Program Files\Go\bin\go.exe"
}

$srcDir = $PSScriptRoot
$rootDir = Join-Path $srcDir "..\.."
$binDir = Join-Path $rootDir "bin"

New-Item -ItemType Directory -Path (Join-Path $binDir "windows_amd64") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $binDir "linux_amd64") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $binDir "linux_arm64") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $binDir "darwin_amd64") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $binDir "darwin_arm64") -Force | Out-Null

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  Building Universal Vault Native CLI Binaries (Go)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

Push-Location $srcDir
try {
    # 1. Windows x86_64
    Write-Host "[*] Building Windows AMD64 binary..." -ForegroundColor Yellow
    $env:GOOS = "windows"; $env:GOARCH = "amd64"; $env:CGO_ENABLED = "0"
    & $goExe build -ldflags="-s -w" -o (Join-Path $binDir "windows_amd64\vault.exe") .
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[+] Created: bin/windows_amd64/vault.exe" -ForegroundColor Green
        Copy-Item (Join-Path $binDir "windows_amd64\vault.exe") (Join-Path $rootDir "installers\windows\vault.exe") -Force
    }

    # 2. Linux x86_64 & ARM64
    Write-Host "[*] Building Linux AMD64 & ARM64 binaries..." -ForegroundColor Yellow
    $env:GOOS = "linux"; $env:GOARCH = "amd64"; $env:CGO_ENABLED = "0"
    & $goExe build -ldflags="-s -w" -o (Join-Path $binDir "linux_amd64/vault") .
    if ($LASTEXITCODE -eq 0) { Write-Host "[+] Created: bin/linux_amd64/vault" -ForegroundColor Green }

    $env:GOOS = "linux"; $env:GOARCH = "arm64"; $env:CGO_ENABLED = "0"
    & $goExe build -ldflags="-s -w" -o (Join-Path $binDir "linux_arm64/vault") .
    if ($LASTEXITCODE -eq 0) { Write-Host "[+] Created: bin/linux_arm64/vault" -ForegroundColor Green }

    # 3. macOS Intel & Apple Silicon
    Write-Host "[*] Building macOS AMD64 & ARM64 (Apple Silicon) binaries..." -ForegroundColor Yellow
    $env:GOOS = "darwin"; $env:GOARCH = "amd64"; $env:CGO_ENABLED = "0"
    & $goExe build -ldflags="-s -w" -o (Join-Path $binDir "darwin_amd64/vault") .
    if ($LASTEXITCODE -eq 0) { Write-Host "[+] Created: bin/darwin_amd64/vault" -ForegroundColor Green }

    $env:GOOS = "darwin"; $env:GOARCH = "arm64"; $env:CGO_ENABLED = "0"
    & $goExe build -ldflags="-s -w" -o (Join-Path $binDir "darwin_arm64/vault") .
    if ($LASTEXITCODE -eq 0) { Write-Host "[+] Created: bin/darwin_arm64/vault" -ForegroundColor Green }

    Write-Host "`nAll CLI binaries compiled successfully!" -ForegroundColor Green
} finally {
    Pop-Location
}
