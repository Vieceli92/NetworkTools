@echo off
rem Atualiza os scripts com a versao mais nova do GitHub (mantem o seu config.psd1)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Atualizar-MobaTools.ps1"
echo.
pause
