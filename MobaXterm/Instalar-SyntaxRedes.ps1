<#
.SYNOPSIS
    Instala os perfis de cores de redes (Cisco/Huawei/Juniper) no MobaXterm.ini.

.DESCRIPTION
    Copia cada perfil de Syntax-Redes.ini para o MobaXterm.ini como [CustomSyntaxN]:
      - "Custom: Redes (Cisco/Huawei/Juniper)"  (completo)
      - "Custom: Redes compacto"                (regras menores, caso o completo nao colora)
    Se o perfil ja existir (mesmo Name=), ele e atualizado no mesmo slot; senao vai
    para o proximo slot livre. -Slot escolhe o slot do perfil completo (ex.: -Slot 3
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

# Le os perfis de Syntax-Redes.ini (cada secao [CustomSyntax...] e um perfil)
$perfis = [Collections.Generic.List[object]]::new()
foreach ($l in [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'Syntax-Redes.ini'), $latin1)) {
    if ($l -match '^\s*;' -or -not $l.Trim()) { continue }
    if ($l -match '^\[') { $perfis.Add([Collections.Generic.List[string]]::new()); continue }
    if ($perfis.Count) { $perfis[$perfis.Count - 1].Add($l) }
}

$linhas = [Collections.Generic.List[string]]::new([IO.File]::ReadAllLines($Ini, $latin1))
$resumo = @()
$primeiro = $true
foreach ($perfil in $perfis) {
    $nome = ($perfil | Where-Object { $_ -like 'Name=*' }) -replace '^Name='

    # Mapeia os slots existentes: numero -> Name
    $slots = @{}; $atual = $null
    foreach ($l in $linhas) {
        if ($l -match '^\[CustomSyntax(\d+)\]$') { $atual = [int]$Matches[1]; $slots[$atual] = ''; continue }
        if ($l -match '^\[') { $atual = $null; continue }
        if ($atual -and $l -match '^Name=(.*)$') { $slots[$atual] = $Matches[1] }
    }
    $alvo = if ($primeiro -and $Slot -gt 0) { $Slot } else {
        $existente = $slots.Keys | Where-Object { $slots[$_] -eq $nome } | Select-Object -First 1
        if ($existente) { $existente } else { (@($slots.Keys) + 0 | Measure-Object -Maximum).Maximum + 1 }
    }
    $primeiro = $false

    # Remove a secao do slot escolhido (se existir) e grava a nova no lugar
    $inicio = $linhas.IndexOf("[CustomSyntax$alvo]")
    if ($inicio -ge 0) {
        $fim = $inicio + 1
        while ($fim -lt $linhas.Count -and $linhas[$fim] -notmatch '^\[') { $fim++ }
        $linhas.RemoveRange($inicio, $fim - $inicio)
    } else {
        $inicio = $linhas.Count
        if ($inicio -gt 0 -and $linhas[$inicio - 1] -ne '') { $linhas.Add(''); $inicio++ }
    }
    $linhas.InsertRange($inicio, [string[]](@("[CustomSyntax$alvo]") + $perfil + ''))
    $resumo += "  [CustomSyntax$alvo] $nome"
}

if ($PSCmdlet.ShouldProcess($Ini, "Gravar $($perfis.Count) perfil(is) de cores")) {
    $bak = '{0}.bak_{1:yyyyMMdd_HHmmss_fff}' -f $Ini, (Get-Date)
    Copy-Item -LiteralPath $Ini -Destination $bak
    [IO.File]::WriteAllText($Ini, (($linhas -join "`r`n") + "`r`n"), $latin1)
    Write-Output "Perfis instalados em $Ini (backup: $bak)"
    $resumo | Write-Output
}
