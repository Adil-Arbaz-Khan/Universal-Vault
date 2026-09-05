@echo off
setlocal
title Universal Vault CLI Uninstaller
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$target=Join-Path $env:LOCALAPPDATA 'UniversalVault\bin'; $dest=Join-Path $target 'vault.exe'; Write-Host '======================================================================' -ForegroundColor Cyan; Write-Host '  Universal Vault CLI -- Uninstaller' -ForegroundColor Cyan; Write-Host '======================================================================' -ForegroundColor Cyan; if(Test-Path $dest){Remove-Item -Path $dest -Force; Write-Host ('[+] Removed: ' + $dest) -ForegroundColor Green}; $userPath=[Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User); if($userPath){$pathEntries=$userPath -split ';'|Where-Object{$_ -ne '' -and $_ -ne $target}; $newUserPath=$pathEntries -join ';'; [Environment]::SetEnvironmentVariable('Path', $newUserPath, [EnvironmentVariableTarget]::User); Write-Host ('[+] Cleanly removed ' + $target + ' from User PATH') -ForegroundColor Green}; Write-Host ''; Write-Host 'Uninstallation Complete.' -ForegroundColor Cyan"
echo.
pause
