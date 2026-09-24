<#
.SYNOPSIS
    Organiza os logs do MobaXterm em pastas Ano\Mes\Dia.

.DESCRIPTION
    Move os arquivos de log soltos da pasta de logs do MobaXterm para
        <Destino>\2026\09-Setembro\24\arquivo.log
    A data vem do nome do arquivo (ex.: 20260924, 2026-09-24) e, se nao tiver,
    da data da ultima alteracao. Arquivos em uso (sessao aberta) sao ignorados.
    Opcionalmente compacta meses antigos em .zip e apaga logs muito antigos.
    Todas as opcoes padrao ficam em config.psd1; os parametros abaixo sobrescrevem.

.EXAMPLE
    .\Organizar-LogsMoba.ps1
.EXAMPLE
    .\Organizar-LogsMoba.ps1 -PastaLogs 'D:\Logs\Moba' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PastaLogs,
    [string]$PastaDestino,
    [int]$MinutosIgnorar = -1,
    [int]$CompactarAposMeses = -1,
    [int]$ApagarAposDias = -1
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
$cfg = Get-MobaConfig

if ($PastaLogs)              { $cfg.PastaLogs = Expand-Caminho $PastaLogs }
if ($PastaDestino)           { $cfg.PastaDestino = Expand-Caminho $PastaDestino }
if (-not $cfg.PastaLogs)     { $cfg.PastaLogs = Get-MobaPastaLogs $cfg }
if (-not $cfg.PastaDestino)  { $cfg.PastaDestino = $cfg.PastaLogs }
if ($MinutosIgnorar -ge 0)   { $cfg.MinutosIgnorar = $MinutosIgnorar }
if ($CompactarAposMeses -ge 0) { $cfg.CompactarAposMeses = $CompactarAposMeses }
if ($ApagarAposDias -ge 0)   { $cfg.ApagarAposDias = $ApagarAposDias }

$Meses = 'Janeiro','Fevereiro','Marco','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'
$ArquivoHistorico = Join-Path $cfg.PastaDestino '_organizador.log'

function Write-Historico([string]$Mensagem) {
    $linha = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Mensagem
    Write-Verbose $linha
    if (-not $WhatIfPreference) { Add-Content -LiteralPath $ArquivoHistorico -Value $linha -Encoding UTF8 }
}

function Get-DataDoLog([IO.FileInfo]$Arquivo) {
    # Usa a ULTIMA data do nome: no formato do Moba (&S-&U-[@&H]&P-(&T)) o horario (&T)
    # vem no fim, depois de host/IP/porta.
    # 1) 20260924, 2026-09-24, 2026_09_24, 2026.09.24
    $m = [regex]::Matches($Arquivo.BaseName, '(?<!\d)(20\d{2})[-_.]?(0[1-9]|1[0-2])[-_.]?(0[1-9]|[12]\d|3[01])(?!\d)')
    for ($i = $m.Count - 1; $i -ge 0; $i--) {
        try { return [datetime]::new([int]$m[$i].Groups[1].Value, [int]$m[$i].Groups[2].Value, [int]$m[$i].Groups[3].Value) } catch { }
    }
    # 2) 24-09-2026 / 24.09.2026 (formato brasileiro)
    $m = [regex]::Matches($Arquivo.BaseName, '(?<!\d)(0[1-9]|[12]\d|3[01])[-_.](0[1-9]|1[0-2])[-_.](20\d{2})(?!\d)')
    for ($i = $m.Count - 1; $i -ge 0; $i--) {
        try { return [datetime]::new([int]$m[$i].Groups[3].Value, [int]$m[$i].Groups[2].Value, [int]$m[$i].Groups[1].Value) } catch { }
    }
    # 3) data de alteracao do arquivo
    return $Arquivo.LastWriteTime
}

function Test-ArquivoEmUso([IO.FileInfo]$Arquivo) {
    try {
        $fs = [IO.File]::Open($Arquivo.FullName, 'Open', 'ReadWrite', 'None')
        $fs.Close()
        return $false
    } catch { return $true }
}

function Get-CaminhoLivre([string]$Caminho) {
    # Evita sobrescrever: arquivo.log -> arquivo_1.log, arquivo_2.log ...
    if (-not (Test-Path -LiteralPath $Caminho)) { return $Caminho }
    $dir  = Split-Path $Caminho -Parent
    $nome = [IO.Path]::GetFileNameWithoutExtension($Caminho)
    $ext  = [IO.Path]::GetExtension($Caminho)
    $i = 1
    do { $novo = Join-Path $dir ('{0}_{1}{2}' -f $nome, $i++, $ext) } while (Test-Path -LiteralPath $novo)
    return $novo
}

if (-not (Test-Path -LiteralPath $cfg.PastaLogs)) { throw "Pasta de logs nao existe: $($cfg.PastaLogs)" }
if (-not (Test-Path -LiteralPath $cfg.PastaDestino)) { New-Item -ItemType Directory -Path $cfg.PastaDestino -Force | Out-Null }

# ---------------------------------------------------------------- 1) Organizar
$limite = (Get-Date).AddMinutes(-$cfg.MinutosIgnorar)
$arquivos = foreach ($ext in $cfg.Extensoes) { Get-ChildItem -LiteralPath $cfg.PastaLogs -Filter $ext -File }
$arquivos = $arquivos | Where-Object { $_.FullName -ne $ArquivoHistorico } | Sort-Object FullName -Unique

$movidos = 0; $pulados = 0
foreach ($arq in $arquivos) {
    if ($arq.LastWriteTime -gt $limite -or (Test-ArquivoEmUso $arq)) { $pulados++; continue }

    $data = Get-DataDoLog $arq
    $pasta = [IO.Path]::Combine($cfg.PastaDestino, $data.ToString('yyyy'), ('{0:D2}-{1}' -f $data.Month, $Meses[$data.Month - 1]), $data.ToString('dd'))
    $alvo = Get-CaminhoLivre (Join-Path $pasta $arq.Name)

    if ($PSCmdlet.ShouldProcess($arq.FullName, "Mover para $alvo")) {
        New-Item -ItemType Directory -Path $pasta -Force | Out-Null
        Move-Item -LiteralPath $arq.FullName -Destination $alvo
        Write-Historico "MOVIDO  $($arq.Name) -> $alvo"
        $movidos++
    }
}

# ------------------------------------------------- 2) Compactar meses antigos
if ($cfg.CompactarAposMeses -gt 0) {
    $corte = (Get-Date -Day 1).Date.AddMonths(-$cfg.CompactarAposMeses)
    Get-ChildItem -LiteralPath $cfg.PastaDestino -Directory | Where-Object Name -match '^20\d{2}$' | ForEach-Object {
        $ano = [int]$_.Name
        Get-ChildItem -LiteralPath $_.FullName -Directory | Where-Object Name -match '^(\d{2})-' | ForEach-Object {
            $inicioMes = [datetime]::new($ano, [int]$Matches[1], 1)
            if ($inicioMes -lt $corte) {
                $zip = "$($_.FullName).zip"
                if ($PSCmdlet.ShouldProcess($_.FullName, "Compactar em $zip")) {
                    Compress-Archive -Path (Join-Path $_.FullName '*') -DestinationPath $zip -Update
                    Remove-Item -LiteralPath $_.FullName -Recurse -Force
                    Write-Historico "ZIP     $zip"
                }
            }
        }
    }
}

# --------------------------------------------------- 3) Apagar logs antigos
if ($cfg.ApagarAposDias -gt 0) {
    $corte = (Get-Date).AddDays(-$cfg.ApagarAposDias)
    Get-ChildItem -LiteralPath $cfg.PastaDestino -Recurse -File |
        Where-Object { $_.LastWriteTime -lt $corte -and $_.DirectoryName -ne $cfg.PastaDestino } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, 'Apagar')) {
                Remove-Item -LiteralPath $_.FullName -Force
                Write-Historico "APAGADO $($_.FullName)"
            }
        }
    # remove pastas que ficaram vazias
    Get-ChildItem -LiteralPath $cfg.PastaDestino -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
        ForEach-Object { if ($PSCmdlet.ShouldProcess($_.FullName, 'Remover pasta vazia')) { Remove-Item -LiteralPath $_.FullName } }
}

Write-Output ("Logs organizados: {0} movido(s), {1} ignorado(s) (em uso/recentes). Destino: {2}" -f $movidos, $pulados, $cfg.PastaDestino)
