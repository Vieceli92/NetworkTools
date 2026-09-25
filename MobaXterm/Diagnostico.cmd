@echo off
rem Confere a instalacao (Moba, ini, logs, cores, AutoHotkey, atalhos) e mostra o que esta errado
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Diagnosticar-MobaTools.ps1"
echo.
pause
