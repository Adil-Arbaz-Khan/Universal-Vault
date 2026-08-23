@echo off
setlocal
cd /d "%~dp0"
echo =======================================================
echo         UNIVERSAL VAULT - CHECK STATUS
echo =======================================================
echo Inspecting files across directory...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\header_vault.ps1" -Action Status -Path "%~dp0."
echo.
pause
