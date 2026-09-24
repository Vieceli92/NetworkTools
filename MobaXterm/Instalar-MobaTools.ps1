<#
.SYNOPSIS
    Cria o atalho "MobaXterm (logs)" e (opcional) uma tarefa agendada que organiza os logs.

.DESCRIPTION
    - Atalho na Area de Trabalho e no Menu Iniciar que abre o MobaXterm pelo
      Iniciar-MobaXterm.ps1 (organiza os logs ao abrir e ao fechar o Moba).
      Depois voce pode fixar esse atalho na barra de tarefas no lugar do original.
    - -TarefaAgendada: organiza os logs no logon do Windows e a cada N horas,
      mesmo se voce abrir o Moba pelo atalho normal.

.EXAMPLE
    .\Instalar-MobaTools.ps1 -TarefaAgendada -IntervaloHoras 1
.EXAMPLE
    .\Instalar-MobaTools.ps1 -Remover
#>
param(
    [switch]$TarefaAgendada,
    [int]$IntervaloHoras = 1,
    [switch]$Remover
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
$cfg = Get-MobaConfig

$nomeAtalho = 'MobaXterm (logs).lnk'
$atalhos = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) $nomeAtalho),
    (Join-Path ([Environment]::GetFolderPath('Programs')) $nomeAtalho)
)
$nomeTarefa = 'MobaXterm - Organizar logs'

if ($Remover) {
    $atalhos | Where-Object { Test-Path -LiteralPath $_ } | Remove-Item -Force
    Unregister-ScheduledTask -TaskName $nomeTarefa -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output 'Atalhos e tarefa agendada removidos.'
    return
}

$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$launcher = Join-Path $PSScriptRoot 'Iniciar-MobaXterm.ps1'
$organizador = Join-Path $PSScriptRoot 'Organizar-LogsMoba.ps1'

$shell = New-Object -ComObject WScript.Shell
foreach ($caminho in $atalhos) {
    $lnk = $shell.CreateShortcut($caminho)
    $lnk.TargetPath = $ps
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcher`""
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.WindowStyle = 7   # minimizado (evita piscar a janela do PowerShell)
    if (Test-Path -LiteralPath $cfg.MobaExe) { $lnk.IconLocation = "$($cfg.MobaExe),0" }
    $lnk.Description = 'Abre o MobaXterm e organiza os logs por data'
    $lnk.Save()
    Write-Output "Atalho criado: $caminho"
}

if ($TarefaAgendada) {
    $acao = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$organizador`""
    $gatilhoLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $gatilhoRepetir = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours $IntervaloHoras)
    $opcoes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $nomeTarefa -Action $acao -Trigger $gatilhoLogon, $gatilhoRepetir -Settings $opcoes `
        -Description 'Organiza os logs do MobaXterm em pastas Ano\Mes\Dia' -Force | Out-Null
    Write-Output "Tarefa agendada criada: '$nomeTarefa' (no logon e a cada $IntervaloHoras h)."
}
