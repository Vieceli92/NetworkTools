@echo off
rem Cria os atalhos "MobaXterm (logs)" e "Pesquisar logs Moba" (Area de Trabalho e Menu Iniciar)
rem e baixa o AutoHotkey v2 portatil para o anti-idle, se ainda nao existir.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Recurse | Unblock-File; & .\Instalar-MobaTools.ps1; Write-Host; & .\Instalar-AutoHotkey.ps1"
echo.
pause
