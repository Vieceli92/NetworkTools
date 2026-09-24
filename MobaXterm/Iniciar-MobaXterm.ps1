<#
.SYNOPSIS
    Launcher do MobaXterm: organiza os logs e depois abre o Moba.

.DESCRIPTION
    Use este script no lugar do atalho normal do MobaXterm (o Instalar-MobaTools.ps1
    cria o atalho para voce). Ele:
      1. Organiza os logs (Organizar-LogsMoba.ps1)
      2. Abre o MobaXterm (com -i <ini do OneDrive>, se configurado em config.psd1)
      3. Se OrganizarAoFechar = $true, espera o Moba fechar e organiza de novo
    Parametros extras sao repassados ao MobaXterm (ex.: -bookmark "Switch-Core").
#>
param([Parameter(ValueFromRemainingArguments)][string[]]$ArgsMoba)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
$cfg = Get-MobaConfig
$organizador = Join-Path $PSScriptRoot 'Organizar-LogsMoba.ps1'

try { & $organizador | Out-Null } catch { Write-Warning "Falha ao organizar logs: $_" }

if (-not (Test-Path -LiteralPath $cfg.MobaExe)) { throw "MobaXterm nao encontrado em '$($cfg.MobaExe)'. Ajuste MobaExe no config.psd1." }

$argumentos = @()
if ($cfg.MobaIni) {
    if (-not (Test-Path -LiteralPath $cfg.MobaIni)) { throw "MobaXterm.ini nao encontrado em '$($cfg.MobaIni)' (o OneDrive ja sincronizou?)." }
    $argumentos += '-i', ('"{0}"' -f $cfg.MobaIni)
}
# Start-Process nao coloca aspas sozinho: "NE BNG" viraria dois argumentos
if ($ArgsMoba) { $argumentos += $ArgsMoba | ForEach-Object { if ($_ -match '\s' -and $_ -notmatch '^".*"$') { '"{0}"' -f $_ } else { $_ } } }

$inicio = @{ FilePath = $cfg.MobaExe; PassThru = $true }
if ($argumentos) { $inicio.ArgumentList = $argumentos }
$proc = Start-Process @inicio

if ($cfg.AntiIdle) {
    $ahk = Join-Path $PSScriptRoot 'AntiIdle\MobaAntiIdle.ahk'
    $motor = @(
        (Join-Path $PSScriptRoot 'AntiIdle\AutoHotkey64.exe'),
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($motor) {
        $seg = if ($cfg.AntiIdleSegundos) { $cfg.AntiIdleSegundos } else { 240 }
        Start-Process -FilePath $motor -ArgumentList ('"{0}"' -f $ahk), $seg
    } else {
        Write-Warning 'AntiIdle ligado, mas o AutoHotkey v2 nao foi encontrado (instale ou coloque AutoHotkey64.exe na pasta AntiIdle).'
    }
}

if ($cfg.OrganizarAoFechar) {
    $proc.WaitForExit()
    try { & $organizador | Out-Null } catch { Write-Warning "Falha ao organizar logs: $_" }
}
