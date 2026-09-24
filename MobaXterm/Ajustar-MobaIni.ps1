<#
.SYNOPSIS
    Ajusta logs, X server e SSH no MobaXterm.ini (ou num .mobaconf exportado).

.DESCRIPTION
    Com o MobaXterm FECHADO:
      1. Troca o formato do nome do log:  &S-&U-[@&H]&P-(&T)  ->  &S_&H_&T
         (sem [ ] ( ) @ e espacos, sem usuario/porta repetidos)
      2. Renomeia sessoes que terminam com " (algo)", ex.: "NE40-BGP (routerx)" -> "NE40-BGP"
         (so se nao existir outra sessao com o mesmo nome na mesma pasta)
      3. Garante LogFolder=_MobaFolder_\Log e log ligado
      4. X server: inicia junto com o MobaXterm (XAuto=1)
      5. SSH: desliga GSSAPI/Kerberos (UseGSSAPI=0), que so atrasa o login em roteador
    -SoLogs faz apenas os itens 1 a 3.
    Faz backup antes (.bak_AAAAMMDD_HHMMSS_fff). Use -WhatIf para so ver o que mudaria.

.EXAMPLE
    .\Ajustar-MobaIni.ps1 -WhatIf
.EXAMPLE
    .\Ajustar-MobaIni.ps1 -Ini 'C:\temp\MobaXterm_configuration.mobaconf' -Saida 'C:\temp\ajustado.mobaconf'
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Ini,
    # Arquivo de saida. Vazio = grava no proprio arquivo (com backup)
    [string]$Saida,
    [string]$Formato = '&S_&H_&T',
    [string]$PastaLogsMoba = '_MobaFolder_\Log',
    [switch]$NaoRenomearSessoes,
    [switch]$SoLogs
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
$latin1 = [Text.Encoding]::GetEncoding(28591)

if (-not $Ini) {
    $cfg = Get-MobaConfig
    $Ini = if ($cfg.MobaIni) { $cfg.MobaIni } else { Find-MobaIni -MobaExe $cfg.MobaExe }
}
if (-not $Ini -or -not (Test-Path -LiteralPath $Ini)) { throw 'MobaXterm.ini nao encontrado. Informe com -Ini.' }
if (-not $Saida -and (Get-Process -Name 'MobaXterm*' -ErrorAction SilentlyContinue)) {
    throw 'Feche o MobaXterm antes (ele regrava o ini ao sair e desfaria a alteracao).'
}

$linhas = [Collections.Generic.List[string]]::new([IO.File]::ReadAllLines($Ini, $latin1))
$mudancas = [Collections.Generic.List[string]]::new()

function Set-Valor([string]$Secao, [string]$Chave, [string]$Valor) {
    $dentro = $false
    for ($i = 0; $i -lt $linhas.Count; $i++) {
        if ($linhas[$i] -match '^\[(.+)\]$') { $dentro = ($Matches[1] -eq $Secao); continue }
        if ($dentro -and $linhas[$i] -match ('^' + [regex]::Escape($Chave) + '=(.*)$')) {
            if ($Matches[1] -ne $Valor) { $mudancas.Add("[$Secao] $Chave : '$($Matches[1])' -> '$Valor'"); $linhas[$i] = "$Chave=$Valor" }
            return
        }
    }
    $pos = $linhas.IndexOf("[$Secao]")
    if ($pos -lt 0) { throw "Secao [$Secao] nao encontrada em $Ini" }
    $linhas.Insert($pos + 1, "$Chave=$Valor"); $mudancas.Add("[$Secao] $Chave : (novo) '$Valor'")
}

# 1) e 3) formato, pasta e log ligado
Set-Valor 'Misc' 'LogFileFormat' $Formato
Set-Valor 'Misc' 'LogFolder' $PastaLogsMoba
Set-Valor 'Misc' 'LogTerminalActivity' '1'

# 4) e 5) X server e SSH
if (-not $SoLogs) {
    Set-Valor 'Misc' 'XAuto' '1'
    Set-Valor 'SSH' 'UseGSSAPI' '0'
}

# 2) renomear sessoes "Nome (algo)" -> "Nome"
if (-not $NaoRenomearSessoes) {
    $renomes = @{}
    $secao = $null
    # primeiro passo: nomes existentes por secao de Bookmarks
    $porSecao = @{}
    foreach ($l in $linhas) {
        if ($l -match '^\[(.+)\]$') { $secao = $Matches[1]; continue }
        if ($secao -like 'Bookmarks*' -and $l -match '^([^=]+)=#') {
            if (-not $porSecao[$secao]) { $porSecao[$secao] = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase) }
            [void]$porSecao[$secao].Add($Matches[1])
        }
    }
    $secao = $null
    for ($i = 0; $i -lt $linhas.Count; $i++) {
        if ($linhas[$i] -match '^\[(.+)\]$') { $secao = $Matches[1]; continue }
        if ($secao -notlike 'Bookmarks*' -or $linhas[$i] -notmatch '^(.+?) \([^()]*\)=(#.*)$') { continue }
        $antigo = ($linhas[$i] -split '=', 2)[0]; $novo = $Matches[1].Trim(); $resto = $Matches[2]
        if ($porSecao[$secao].Contains($novo)) { $mudancas.Add("Sessao '$antigo' mantida: ja existe '$novo' na mesma pasta"); continue }
        $linhas[$i] = "$novo=$resto"
        [void]$porSecao[$secao].Add($novo)
        $renomes[$antigo] = $novo
        $mudancas.Add("Sessao '$antigo' -> '$novo'")
    }
    # LastSession=Nome|... aponta para a sessao pelo nome
    for ($i = 0; $i -lt $linhas.Count; $i++) {
        if ($linhas[$i] -match '^LastSession=([^|]+)\|(.*)$' -and $renomes.ContainsKey($Matches[1])) {
            $linhas[$i] = "LastSession=$($renomes[$Matches[1]])|$($Matches[2])"
        }
    }
}

if ($mudancas.Count -eq 0) { Write-Output 'Nada a ajustar: o ini ja esta no formato.'; return }
$mudancas | ForEach-Object { Write-Output "  $_" }

$destino = if ($Saida) { $Saida } else { $Ini }
if ($PSCmdlet.ShouldProcess($destino, "Gravar $($mudancas.Count) ajuste(s)")) {
    if (-not $Saida) {
        $bak = '{0}.bak_{1:yyyyMMdd_HHmmss_fff}' -f $Ini, (Get-Date)
        Copy-Item -LiteralPath $Ini -Destination $bak
        Write-Output "Backup: $bak"
    }
    [IO.File]::WriteAllText($destino, (($linhas -join "`r`n") + "`r`n"), $latin1)
    Write-Output "Gravado: $destino"
    Write-Output 'Logs NOVOS usam o formato novo; os antigos continuam com o nome antigo (o organizador entende os dois).'
}
