<#
.SYNOPSIS
    Mostra quais chaves do MobaXterm.ini mudaram quando voce altera algo na tela do Moba.

.DESCRIPTION
    Serve para descobrir onde o Moba grava cada opcao (muitas nao sao documentadas):
      1. Com o Moba FECHADO:   .\Comparar-MobaIni.ps1 -Foto
      2. Abra o Moba, mude as opcoes na tela, clique OK e FECHE o Moba
      3. .\Comparar-MobaIni.ps1            -> lista as chaves que mudaram
    Senhas, host keys e posicoes de janela sao ignoradas. Nada no ini e alterado.
    A lista fica tambem em %TEMP%\MobaTools\mudancas-ini.txt (pode mandar para quem ajuda).
#>
param([switch]$Foto, [string]$Ini)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
$cfg = Get-MobaConfig
if (-not $Ini) { $Ini = if ($cfg.MobaIni) { $cfg.MobaIni } else { Find-MobaIni -MobaExe $cfg.MobaExe } }
if (-not $Ini -or -not (Test-Path -LiteralPath $Ini)) { throw 'MobaXterm.ini nao encontrado. Informe com -Ini.' }
if (Get-Process -Name 'MobaXterm*' -ErrorAction SilentlyContinue) { throw 'Feche o MobaXterm antes (ele so grava o ini ao fechar).' }

$pasta = Join-Path ([IO.Path]::GetTempPath()) 'MobaTools'
New-Item -ItemType Directory -Path $pasta -Force | Out-Null
$arqFoto = Join-Path $pasta 'foto-MobaXterm.ini'
$ignorar = '^(Passwords|Sesspass|SSH_Hostkeys|WindowPos.*|DiffWindowPos.*|EditorWindowPos.*|ImportExportSpecials)$'

function Read-Ini([string]$Arquivo) {
    $r = [ordered]@{}; $secao = ''
    foreach ($l in [IO.File]::ReadAllLines($Arquivo, [Text.Encoding]::GetEncoding(28591))) {
        if ($l -match '^\[(.+)\]$') { $secao = $Matches[1]; continue }
        if ($secao -match $ignorar -or $l -notmatch '^([^=]+)=(.*)$') { continue }
        $r["[$secao] $($Matches[1])"] = $Matches[2]
    }
    return $r
}

if ($Foto) {
    Copy-Item -LiteralPath $Ini -Destination $arqFoto -Force
    Write-Host "Foto tirada de $Ini" -ForegroundColor Green
    Write-Host 'Agora abra o Moba, mude as opcoes, clique OK, FECHE o Moba e rode este script de novo (sem -Foto).'
    return
}
if (-not (Test-Path -LiteralPath $arqFoto)) { throw 'Tire a foto antes: .\Comparar-MobaIni.ps1 -Foto (com o Moba fechado).' }

$antes = Read-Ini $arqFoto
$depois = Read-Ini $Ini
function Resumo([string]$V) { if ($null -eq $V) { return '(nao existia)' } if ($V.Length -gt 120) { return $V.Substring(0, 117) + '...' } return $V }

$saida = @()
foreach ($k in @($antes.Keys) + @($depois.Keys) | Sort-Object -Unique) {
    $a = $antes[$k]; $d = $depois[$k]
    if ($a -ceq $d) { continue }
    $saida += "$k"
    $saida += "    antes : $(Resumo $a)"
    $saida += "    depois: $(Resumo $d)"
    # sessoes: mostra so os campos (separados por %) que mudaram
    if ($a -and $d -and $a.Contains('%') -and $d.Contains('%')) {
        $ca = $a -split '%'; $cd = $d -split '%'
        for ($i = 0; $i -lt [Math]::Max($ca.Count, $cd.Count); $i++) {
            if ($ca[$i] -cne $cd[$i]) { $saida += "    campo $i : '$($ca[$i])' -> '$($cd[$i])'" }
        }
    }
}
if (-not $saida) { Write-Host 'Nenhuma mudanca. Voce clicou OK e FECHOU o Moba antes de rodar?' -ForegroundColor Yellow; return }
$arqSaida = Join-Path $pasta 'mudancas-ini.txt'
Set-Content -LiteralPath $arqSaida -Value $saida -Encoding UTF8
$saida | ForEach-Object { Write-Host $_ }
Write-Host "`nSalvo em: $arqSaida" -ForegroundColor Cyan
