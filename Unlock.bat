@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =======================================================
echo         UNIVERSAL VAULT - TARGET UNLOCKER
echo =======================================================

set "TARGET=%~1"

if "%TARGET%"=="" (
    echo [1] Unlock entire current folder tree
    echo [2] Unlock a specific folder or file
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
echo Restoring file headers in-place...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\header_vault.ps1" -Action Unlock -Path "!TARGET!"

echo.
pause
