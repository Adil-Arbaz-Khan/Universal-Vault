@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =======================================================
echo    UNIVERSAL VAULT V5.5.3 - AUTHENTICATED AEAD LOCKER
echo =======================================================

set "TARGET=%~1"
set "GIBBERISH_OPT="

:: Check if command line argument specifies -g or --gibberish
if /i "%~2"=="-g" set "GIBBERISH_OPT=--gibberish"
if /i "%~2"=="--gibberish" set "GIBBERISH_OPT=--gibberish"
if /i "%~1"=="-g" (
    set "GIBBERISH_OPT=--gibberish"
    set "TARGET=%~2"
)
if /i "%~1"=="--gibberish" (
    set "GIBBERISH_OPT=--gibberish"
    set "TARGET=%~2"
)

if "%TARGET%"=="" (
    echo [1] Lock entire current folder tree (in-place names)
    echo [2] Lock entire current folder tree with Gibberish file names
    echo [3] Lock a specific folder or file
    echo.
    set /p "CHOICE=Select an option [1-3, default=1]: "
    if "!CHOICE!"=="2" (
        set "TARGET=%~dp0."
        set "GIBBERISH_OPT=--gibberish"
    ) else if "!CHOICE!"=="3" (
        set /p "TARGET=Enter or drag-and-drop the specific file/folder path: "
        set /p "GIB_ASK=Disguise file name(s) to randomized gibberish? [y/N]: "
        if /i "!GIB_ASK!"=="y" set "GIBBERISH_OPT=--gibberish"
    ) else (
        set "TARGET=%~dp0."
    )
)

:: Strip all surrounding double and single quotes
set "TARGET=!TARGET:"=!"
set "TARGET=!TARGET:'=!"

echo.
echo Target Scope: !TARGET!
if "!GIBBERISH_OPT!"=="--gibberish" (
    echo Filename Masking: ENABLED ^(Randomized 16-hex .vault^)
)
echo Encrypting with 100%% Full-File AEAD (AES-256 + HMAC-SHA256 + 600k PBKDF2)...
echo.

set "PS_GIB="
if "!GIBBERISH_OPT!"=="--gibberish" set "PS_GIB=-Gibberish"

:: Check if Python is available for maximum C-accelerated throughput
where python >nul 2>nul
if %errorlevel% equ 0 (
    python "%~dp0tools\vault.py" lock "!TARGET!" !GIBBERISH_OPT!
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\header_vault.ps1" -Action Lock -Path "!TARGET!" !PS_GIB!
)

echo.
pause
