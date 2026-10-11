@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =======================================================
echo     UNIVERSAL VAULT V5.5.4 - STREAM IN VOLATILE RAM
echo =======================================================

set "TARGET=%~1"

if "%TARGET%"=="" (
    echo Drag and drop or enter the locked file path to view in RAM:
    set /p "TARGET=Target file: "
)

:: Strip all surrounding double and single quotes
set "TARGET=!TARGET:"=!"
set "TARGET=!TARGET:'=!"

echo.
echo Target File: !TARGET!
echo Streaming in volatile RAM with zero disk writes...
echo.

:: Check if Python is available
where python >nul 2>nul
if %errorlevel% equ 0 (
    python "%~dp0tools\vault.py" view "!TARGET!"
) else (
    where vault >nul 2>nul
    if %errorlevel% equ 0 (
        vault view "!TARGET!"
    ) else if exist "%~dp0bin\windows_amd64\vault.exe" (
        "%~dp0bin\windows_amd64\vault.exe" view "!TARGET!"
    ) else (
        echo Error: Neither Python nor native vault CLI found to stream in RAM.
    )
)

echo.
pause
