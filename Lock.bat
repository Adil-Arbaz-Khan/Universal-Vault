@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =======================================================
echo     UNIVERSAL VAULT V4 - MILITARY GRADE LOCKER
echo =======================================================

set "TARGET=%~1"
set "FORCE_FULL="

if "%TARGET%"=="" (
    echo [1] Smart Hybrid Lock (100%% Full Armor for Docs/Images ^<50MB + Fast 9GB+ Media)
    echo [2] Lock a specific folder or file
    echo [3] Force 100%% FULL Encryption on ALL files regardless of size
    echo.
    set /p "CHOICE=Select an option [1, 2, or 3, default=1]: "
    if "!CHOICE!"=="2" (
        set /p "TARGET=Enter or drag-and-drop the specific file/folder path: "
    ) else if "!CHOICE!"=="3" (
        set "TARGET=%~dp0."
        set "FORCE_FULL=-ForceFull"
    ) else (
        set "TARGET=%~dp0."
    )
)

:: Strip all surrounding double and single quotes
set "TARGET=!TARGET:"=!"
set "TARGET=!TARGET:'=!"

echo.
echo Target Scope: !TARGET!
echo Encrypting with 100,000 PBKDF2 iterations + Anti-Brute-Force Armor...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\header_vault.ps1" -Action Lock -Path "!TARGET!" !FORCE_FULL!

echo.
pause
