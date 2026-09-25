@echo off
rem Baixa o AutoHotkey v2 portatil para a pasta AntiIdle (dois cliques)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Instalar-AutoHotkey.ps1"
echo.
pause
