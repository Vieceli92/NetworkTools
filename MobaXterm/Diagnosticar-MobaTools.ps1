<#
.SYNOPSIS
    Confere a instalacao dos scripts do MobaXterm e mostra o que esta errado.

.DESCRIPTION
    Nao altera nada. Verifica: config.psd1, MobaXterm.exe, MobaXterm.ini (e o do AppData),
    pasta de logs, perfis de cores, AutoHotkey, atalhos (se apontam para arquivos que
    existem NESTE PC) e o ultimo log do launcher. Use Diagnostico.cmd (dois cliques).
#>
$ErrorActionPreference = 'Continue'
$problemas = 0

function Ok([string]$T) { Write-Host "  [OK]  $T" -ForegroundColor Green }
function Aviso([string]$T) { Write-Host "  [!]   $T" -ForegroundColor Yellow }
function Erro([string]$T) { Write-Host "  [X]   $T" -ForegroundColor Red; $script:problemas++ }
function Titulo([string]$T) { Write-Host "`n== $T" -ForegroundColor Cyan }

Titulo 'Ambiente'
Write-Host "  PC: $env:COMPUTERNAME   usuario: $env:USERNAME   PowerShell $($PSVersionTable.PSVersion)"
Write-Host "  OneDrive: $env:OneDrive"
Write-Host "  Scripts: $PSScriptRoot"
$versao = Join-Path $PSScriptRoot 'versao.txt'
if (Test-Path -LiteralPath $versao) { Write-Host "  Versao dos scripts: $((Get-Content -LiteralPath $versao) -join ' | ')" }
if (Get-Process -Name 'MobaXterm*' -ErrorAction SilentlyContinue) { Aviso 'MobaXterm esta aberto agora.' }

Titulo 'config.psd1'
try {
    . (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
    $cfg = Get-MobaConfig
    Ok 'config.psd1 carregado'
} catch { Erro "config.psd1 com erro: $($_.Exception.Message)"; return }

Titulo 'MobaXterm'
if ($cfg.MobaExe -and (Test-Path -LiteralPath $cfg.MobaExe)) {
    Ok "MobaExe: $($cfg.MobaExe) (versao $((Get-Item -LiteralPath $cfg.MobaExe).VersionInfo.ProductVersion))"
} else { Erro "MobaExe nao existe: '$($cfg.MobaExe)'. Rode Migrar-ParaPortable.ps1 ou ajuste o config.psd1." }

$ini = if ($cfg.MobaIni) { $cfg.MobaIni } else { Find-MobaIni -MobaExe $cfg.MobaExe }
if ($ini -and (Test-Path -LiteralPath $ini)) {
    Ok "MobaXterm.ini: $ini (alterado $((Get-Item -LiteralPath $ini).LastWriteTime))"
    if (-not $cfg.MobaIni) { Aviso 'MobaIni vazio no config.psd1: o atalho nao passa -i (um Moba instalado usaria o ini do AppData).' }
    $nomes = Select-String -LiteralPath $ini -Pattern '^Name=Custom: Redes' | ForEach-Object { $_.Line -replace '^Name=' }
    if ($nomes) { Ok "Perfis de cores no ini: $($nomes -join ' / ')" } else { Aviso 'Perfis "Custom: Redes" nao estao no ini: rode Instalar-SyntaxRedes.ps1 com o Moba fechado.' }
    $conflitos = Get-ChildItem -LiteralPath (Split-Path $ini) -Filter 'MobaXterm*.ini' -File | Where-Object Name -ne 'MobaXterm.ini'
    foreach ($c in $conflitos) { Aviso "Possivel conflito do OneDrive: $($c.FullName)" }
} else { Erro "MobaXterm.ini nao encontrado: '$ini'" }
$iniAppData = if ($env:APPDATA) { Join-Path $env:APPDATA 'MobaXterm\MobaXterm.ini' }
if ($iniAppData -and (Test-Path -LiteralPath $iniAppData) -and $iniAppData -ne $ini) {
    Aviso "Existe tambem $iniAppData (usado por um Moba INSTALADO). Abra sempre pelo atalho 'MobaXterm (logs)'."
}

Titulo 'Logs'
try {
    $pasta = if ($cfg.PastaLogs) { $cfg.PastaLogs } else { Get-MobaPastaLogs $cfg }
    if (Test-Path -LiteralPath $pasta) {
        $n = @(Get-ChildItem -LiteralPath $pasta -Recurse -File -Include *.log, *.txt -ErrorAction SilentlyContinue).Count
        Ok "Pasta de logs: $pasta ($n arquivo(s))"
    } else { Erro "Pasta de logs nao existe: $pasta" }
} catch { Erro "Pasta de logs: $($_.Exception.Message)" }

Titulo 'Anti-idle'
if ($cfg.AntiIdle) {
    $motor = @((Join-Path $PSScriptRoot 'AntiIdle\AutoHotkey64.exe'),
        $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe' }),
        $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe' })) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if ($motor) { Ok "AutoHotkey: $motor" } else { Aviso 'AutoHotkey nao encontrado: dois cliques em Instalar AntiIdle.cmd (ou AntiIdle = $false).' }
} else { Write-Host '  Anti-idle desligado no config.psd1' }

Titulo 'Atalhos'
try {
    $shell = New-Object -ComObject WScript.Shell
    $pastas = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Desktop'),
        $(if ($env:OneDrive) { Join-Path $env:OneDrive 'Desktop' }), [Environment]::GetFolderPath('Programs')) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique
    $achou = $false
    foreach ($lnk in Get-ChildItem -LiteralPath $pastas -Filter '*.lnk' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Moba' }) {
        $achou = $true
        $a = $shell.CreateShortcut($lnk.FullName)
        $script = $null
        if ($a.Arguments -match '-File "([^"]+)"') { $script = $Matches[1] }
        elseif ($a.Arguments -match "Join-Path \`$env:OneDrive '([^']+)'") { $script = Join-Path $env:OneDrive ($Matches[1] -replace "''", "'") }
        if ($script -and -not (Test-Path -LiteralPath $script)) {
            Erro "$($lnk.FullName)`n        aponta para um arquivo que NAO existe neste PC: $script`n        -> dois cliques em Criar Atalhos.cmd para recriar"
        } elseif ($script) {
            Ok "$($lnk.FullName) -> $script"
            if ($a.Arguments -match '-File "' -and $env:OneDrive -and $script -like "$env:OneDrive*") {
                Aviso '   caminho fixo do OneDrive: se a Area de Trabalho sincroniza, quebra no outro PC. Recrie com Criar Atalhos.cmd.'
            }
        } else { Write-Host "  [ ]   $($lnk.FullName) -> $($a.TargetPath) $($a.Arguments)" }
    }
    if (-not $achou) { Aviso 'Nenhum atalho do Moba encontrado: dois cliques em Criar Atalhos.cmd.' }
} catch { Aviso "Nao consegui ler os atalhos: $($_.Exception.Message)" }

Titulo 'Ultimas linhas do log do launcher'
$log = Join-Path ([IO.Path]::GetTempPath()) 'MobaTools\iniciar.log'
if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Tail 8 | ForEach-Object { Write-Host "  $_" } }
else { Write-Host '  (ainda nao existe - abra o Moba pelo atalho "MobaXterm (logs)" uma vez)' }

Write-Host ''
if ($problemas) { Write-Host "$problemas problema(s) encontrado(s). Mande um print desta tela se precisar de ajuda." -ForegroundColor Red }
else { Write-Host 'Nenhum problema encontrado.' -ForegroundColor Green }
