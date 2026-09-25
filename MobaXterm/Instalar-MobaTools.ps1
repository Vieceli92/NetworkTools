<#
.SYNOPSIS
    Cria os atalhos "MobaXterm (logs)" e "Pesquisar logs Moba" e (opcional) uma tarefa agendada que organiza os logs.

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
$nomeBusca = 'Pesquisar logs Moba.lnk'
$atalhosBusca = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) $nomeBusca),
    (Join-Path ([Environment]::GetFolderPath('Programs')) $nomeBusca)
)
$nomeTarefa = 'MobaXterm - Organizar logs'

if ($Remover) {
    $atalhos + $atalhosBusca | Where-Object { Test-Path -LiteralPath $_ } | Remove-Item -Force
    Unregister-ScheduledTask -TaskName $nomeTarefa -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output 'Atalhos e tarefa agendada removidos.'
    return
}

$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$launcher = Join-Path $PSScriptRoot 'Iniciar-MobaXterm.ps1'
$organizador = Join-Path $PSScriptRoot 'Organizar-LogsMoba.ps1'

function Get-ArgumentosScript([string]$Script, [switch]$STA) {
    # A Area de Trabalho costuma ser sincronizada pelo OneDrive: um atalho com caminho fixo
    # (C:\Users\<usuario>\OneDrive\...) quebra no outro PC, onde o usuario e diferente.
    # Por isso, se o script estiver no OneDrive, o caminho e montado na hora com $env:OneDrive.
    $base = '-NoProfile -ExecutionPolicy Bypass' + $(if ($STA) { ' -STA' } else { '' }) + ' -WindowStyle Hidden'
    if ($env:OneDrive -and $Script.StartsWith($env:OneDrive.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $Script.Substring($env:OneDrive.TrimEnd('\').Length + 1).Replace("'", "''")
        return "$base -Command `"& (Join-Path `$env:OneDrive '$rel')`""
    }
    return "$base -File `"$Script`""
}

function Get-CaminhoPortatil([string]$Caminho) {
    # %OneDrive%\... no lugar de C:\Users\<usuario>\OneDrive\... (vale nos dois PCs)
    if ($env:OneDrive -and $Caminho.StartsWith($env:OneDrive.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        return '%OneDrive%' + $Caminho.Substring($env:OneDrive.TrimEnd('\').Length)
    }
    return $Caminho
}

$shell = New-Object -ComObject WScript.Shell
foreach ($caminho in $atalhos) {
    $lnk = $shell.CreateShortcut($caminho)
    $lnk.TargetPath = $ps
    $lnk.Arguments = Get-ArgumentosScript $launcher
    $lnk.WorkingDirectory = ''
    $lnk.WindowStyle = 7   # minimizado (evita piscar a janela do PowerShell)
    if (Test-Path -LiteralPath $cfg.MobaExe) { $lnk.IconLocation = "$(Get-CaminhoPortatil $cfg.MobaExe),0" }
    $lnk.Description = 'Abre o MobaXterm e organiza os logs por data'
    $lnk.Save()
    Write-Output "Atalho criado: $caminho"
}

$busca = Join-Path $PSScriptRoot 'Pesquisar-Logs.ps1'
foreach ($caminho in $atalhosBusca) {
    $lnk = $shell.CreateShortcut($caminho)
    $lnk.TargetPath = $ps
    $lnk.Arguments = Get-ArgumentosScript $busca -STA
    $lnk.WorkingDirectory = ''
    $lnk.WindowStyle = 7
    $lnk.IconLocation = '%SystemRoot%\System32\shell32.dll,22'   # lupa
    $lnk.Description = 'Pesquisa nos logs do MobaXterm por hostname, IP ou texto'
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
