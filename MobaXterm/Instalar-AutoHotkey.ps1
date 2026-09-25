<#
.SYNOPSIS
    Baixa o AutoHotkey v2 portatil (AutoHotkey64.exe) para a pasta AntiIdle.

.DESCRIPTION
    O anti-idle (AntiIdle\MobaAntiIdle.ahk) precisa do AutoHotkey v2. Este script baixa o
    zip oficial (autohotkey.com), extrai so o AutoHotkey64.exe para a pasta AntiIdle e
    desbloqueia o arquivo. Como a pasta dos scripts fica no OneDrive, o anti-idle passa a
    funcionar no trabalho e em casa sem instalar nada.

.EXAMPLE
    .\Instalar-AutoHotkey.ps1            # baixa se ainda nao existir
    .\Instalar-AutoHotkey.ps1 -Forcar    # baixa de novo (atualizar)
#>
param([switch]$Forcar)

$ErrorActionPreference = 'Stop'
$url = 'https://www.autohotkey.com/download/ahk-v2.zip'
$pasta = Join-Path $PSScriptRoot 'AntiIdle'
$destino = Join-Path $pasta 'AutoHotkey64.exe'

if ((Test-Path -LiteralPath $destino) -and -not $Forcar) {
    Write-Host "Ja existe: $destino" -ForegroundColor Green
    Write-Host 'Use -Forcar para baixar de novo.'
    return
}

New-Item -ItemType Directory -Path $pasta -Force | Out-Null
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ahk-v2_' + [guid]::NewGuid().ToString('N'))
$zip = "$temp.zip"
try {
    Write-Host "Baixando $url ..."
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $ProgressPreference = 'SilentlyContinue'      # deixa o Invoke-WebRequest bem mais rapido no PowerShell 5.1
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

    Expand-Archive -LiteralPath $zip -DestinationPath $temp -Force
    $exe = Get-ChildItem -LiteralPath $temp -Recurse -Filter 'AutoHotkey64.exe' | Select-Object -First 1
    if (-not $exe) { throw 'AutoHotkey64.exe nao encontrado dentro do zip.' }

    Copy-Item -LiteralPath $exe.FullName -Destination $destino -Force
    try { Unblock-File -LiteralPath $destino } catch { }
    $versao = (Get-Item -LiteralPath $destino).VersionInfo.ProductVersion
    Write-Host "OK: $destino $(if ($versao) { "(versao $versao)" })" -ForegroundColor Green
    Write-Host 'O anti-idle sobe junto quando voce abrir o Moba pelo icone "MobaXterm (logs)".'
} catch {
    Write-Host "Nao foi possivel baixar: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    Write-Host 'Faca manualmente:'
    Write-Host "  1. Baixe $url no navegador"
    Write-Host "  2. Abra o zip e copie o AutoHotkey64.exe para: $pasta"
    Write-Host '  (Se a rede da empresa bloquear o download ou o .exe, use o anti-idle so em casa ou'
    Write-Host '   AntiIdle = $false no config.psd1.)'
} finally {
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
