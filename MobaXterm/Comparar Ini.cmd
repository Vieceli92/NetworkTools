@echo off
rem Descobre quais chaves do MobaXterm.ini mudam quando voce altera algo na tela do Moba
cd /d "%~dp0"
echo 1) Tirando a foto do ini (o Moba precisa estar FECHADO)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Comparar-MobaIni.ps1" -Foto
echo.
echo 2) Abra o Moba, mude as opcoes, clique OK e FECHE o Moba. Depois aperte uma tecla aqui.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Comparar-MobaIni.ps1"
echo.
pause
