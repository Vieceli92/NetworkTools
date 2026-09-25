@echo off
rem Abre a janela de pesquisa/comparacao de logs do MobaXterm (dois cliques)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Pesquisar-Logs.ps1"
