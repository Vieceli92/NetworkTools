<#
.SYNOPSIS
    Instala o perfil de cores "Custom: Redes (Cisco/Huawei/Juniper)" no MobaXterm.ini.

.DESCRIPTION
    Copia a secao de Syntax-Redes.ini para o MobaXterm.ini como [CustomSyntaxN].
    Se o perfil ja existir (mesmo Name=), ele e atualizado no mesmo slot;
    senao vai para o proximo slot livre. Use -Slot para escolher (ex.: -Slot 3
    substitui o "Custom: Cisco (network)" que vem no Moba).
    O MobaXterm precisa estar FECHADO. Um backup do ini e criado antes.

    Depois: Settings > Configuration > Terminal > Syntax highlighting, ou em cada
    sessao: Edit session > Terminal settings > Syntax highlighting.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Ini,
    [int]$Slot = 0
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
$cfg = Get-MobaConfig
$latin1 = [Text.Encoding]::GetEncoding(28591)

if (Get-Process -Name 'MobaXterm*' -ErrorAction SilentlyContinue) { throw 'Feche o MobaXterm antes (ele regrava o ini ao sair e desfaria a alteracao).' }
if (-not $Ini) { $Ini = if ($cfg.MobaIni) { $cfg.MobaIni } else { Find-MobaIni -MobaExe $cfg.MobaExe } }
if (-not $Ini -or -not (Test-Path -LiteralPath $Ini)) { throw 'MobaXterm.ini nao encontrado. Informe com -Ini.' }

# Corpo do perfil (sem comentarios e sem o cabecalho de secao)
$perfil = [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'Syntax-Redes.ini'), $latin1) |
    Where-Object { $_ -and $_ -notmatch '^\s*[;\[]' }
$nome = ($perfil | Where-Object { $_ -like 'Name=*' }) -replace '^Name='

$linhas = [Collections.Generic.List[string]]::new([IO.File]::ReadAllLines($Ini, $latin1))

# Mapeia os slots existentes: numero -> Name
$slots = @{}; $atual = $null
foreach ($l in $linhas) {
    if ($l -match '^\[CustomSyntax(\d+)\]$') { $atual = [int]$Matches[1]; $slots[$atual] = ''; continue }
    if ($l -match '^\[') { $atual = $null; continue }
    if ($atual -and $l -match '^Name=(.*)$') { $slots[$atual] = $Matches[1] }
}
if ($Slot -le 0) {
    $existente = $slots.Keys | Where-Object { $slots[$_] -eq $nome } | Select-Object -First 1
    $Slot = if ($existente) { $existente } else { (@($slots.Keys) + 0 | Measure-Object -Maximum).Maximum + 1 }
}

# Remove a secao do slot escolhido (se existir) e grava a nova
$inicio = $linhas.IndexOf("[CustomSyntax$Slot]")
if ($inicio -ge 0) {
    $fim = $inicio + 1
    while ($fim -lt $linhas.Count -and $linhas[$fim] -notmatch '^\[') { $fim++ }
    $linhas.RemoveRange($inicio, $fim - $inicio)
} else {
    $inicio = $linhas.Count
    if ($inicio -gt 0 -and $linhas[$inicio - 1] -ne '') { $linhas.Add(''); $inicio++ }
}
$bloco = @("[CustomSyntax$Slot]") + $perfil + ''
$linhas.InsertRange($inicio, [string[]]$bloco)

if ($PSCmdlet.ShouldProcess($Ini, "Gravar perfil '$nome' em [CustomSyntax$Slot]")) {
    $bak = '{0}.bak_{1:yyyyMMdd_HHmmss_fff}' -f $Ini, (Get-Date)
    Copy-Item -LiteralPath $Ini -Destination $bak
    [IO.File]::WriteAllText($Ini, (($linhas -join "`r`n") + "`r`n"), $latin1)
    Write-Output "Perfil '$nome' instalado em [CustomSyntax$Slot] de $Ini (backup: $bak)"
}
