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

if ($cfg.OrganizarAoFechar) {
    $proc.WaitForExit()
    try { & $organizador | Out-Null } catch { Write-Warning "Falha ao organizar logs: $_" }
}
