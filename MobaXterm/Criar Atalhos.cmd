@echo off
rem Cria os atalhos "MobaXterm (logs)" e "Pesquisar logs Moba" (Area de Trabalho e Menu Iniciar)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Recurse | Unblock-File; & .\Instalar-MobaTools.ps1"
echo.
pause
