@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =======================================================
echo     UNIVERSAL VAULT V5 - AUTHENTICATED AEAD LOCKER
echo =======================================================

set "TARGET=%~1"

if "%TARGET%"=="" (
    echo [1] Lock entire current folder tree (100%% Full-File AEAD)
    echo [2] Lock a specific folder or file
    echo.
    set /p "CHOICE=Select an option [1 or 2, default=1]: "
    if "!CHOICE!"=="2" (
        set /p "TARGET=Enter or drag-and-drop the specific file/folder path: "
    ) else (
        set "TARGET=%~dp0."
    )
)

:: Strip all surrounding double and single quotes
set "TARGET=!TARGET:"=!"
set "TARGET=!TARGET:'=!"

echo.
echo Target Scope: !TARGET!
echo Encrypting with 100%% Full-File AEAD (AES-256 + HMAC-SHA256 + 250k PBKDF2)...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\header_vault.ps1" -Action Lock -Path "!TARGET!"

echo.
pause
