<#
.SYNOPSIS
    Instala os perfis de cores de redes (Cisco/Huawei/Juniper) no MobaXterm.ini.

.DESCRIPTION
    O MobaXterm tem 8 slots de perfil personalizado ([CustomSyntax1] a [CustomSyntax8]); os
    slots 1 a 3 vem com exemplos do Moba e NAO sao mexidos.
    Cada perfil de Syntax-Redes.ini ("Custom: Redes (Cisco/Huawei/Juniper)" e "Custom: Redes
    compacto") e atualizado no slot onde ja estiver (mesmo Name=); senao vai para o primeiro
    slot livre. Copias duplicadas do mesmo perfil sao removidas. -Slots escolhe os slots
    (ex.: -Slots 4,5).
    O MobaXterm precisa estar FECHADO. Um backup do ini e criado antes.

    Depois: Settings > Configuration > Terminal > Syntax highlighting, ou em cada
    sessao: Edit session > Terminal settings > Syntax highlighting.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Ini,
    # Slots (1 a 8) usados, na ordem dos perfis do Syntax-Redes.ini. Vazio = automatico
    [ValidateRange(1, 8)][int[]]$Slots
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
if ($Slots -and $Slots.Count -lt $perfis.Count) { throw "Informe $($perfis.Count) slots em -Slots (um por perfil)." }

function Get-SlotsIni {
    # numero do slot -> Name
    $r = @{}; $atual = $null
    foreach ($l in $linhas) {
        if ($l -match '^\[CustomSyntax(\d+)\]$') { $atual = [int]$Matches[1]; $r[$atual] = ''; continue }
        if ($l -match '^\[') { $atual = $null; continue }
        if ($atual -and $l -match '^Name=(.*)$') { $r[$atual] = $Matches[1] }
    }
    return $r
}

function Remove-Slot([int]$Num) {
    $i = $linhas.IndexOf("[CustomSyntax$Num]")
    if ($i -lt 0) { return }
    $fim = $i + 1
    while ($fim -lt $linhas.Count -and $linhas[$fim] -notmatch '^\[') { $fim++ }
    $linhas.RemoveRange($i, $fim - $i)
}

$n = 0
foreach ($perfil in $perfis) {
    $nome = ($perfil | Where-Object { $_ -like 'Name=*' }) -replace '^Name='
    $ocupados = Get-SlotsIni
    $meus = @($ocupados.Keys | Where-Object { $ocupados[$_] -eq $nome } | Sort-Object)
    if ($Slots) { $alvo = $Slots[$n] }
    elseif ($meus.Count) { $alvo = $meus[0] }
    else {
        $alvo = 1..8 | Where-Object { -not $ocupados.ContainsKey($_) } | Select-Object -First 1
        if (-not $alvo) { throw "Os 8 slots de perfil estao ocupados. Remova um no Moba (Customize > Remove this custom syntax) ou use -Slots." }
    }
    $n++
    foreach ($d in $meus | Where-Object { $_ -ne $alvo }) { Remove-Slot $d; $resumo += "  removida copia duplicada em [CustomSyntax$d]" }

    # Remove a secao do slot escolhido (se existir) e grava a nova no lugar
    $inicio = $linhas.IndexOf("[CustomSyntax$alvo]")
    if ($inicio -ge 0) {
        $fim = $inicio + 1
        while ($fim -lt $linhas.Count -and $linhas[$fim] -notmatch '^\[') { $fim++ }
        $linhas.RemoveRange($inicio, $fim - $inicio)
    } else {
        # novo slot: logo depois do ultimo [CustomSyntaxN] existente (ou no fim do arquivo)
        $ultimo = -1
        for ($i = 0; $i -lt $linhas.Count; $i++) { if ($linhas[$i] -match '^\[CustomSyntax\d+\]$') { $ultimo = $i } }
        if ($ultimo -ge 0) {
            $inicio = $ultimo + 1
            while ($inicio -lt $linhas.Count -and $linhas[$inicio] -notmatch '^\[') { $inicio++ }
        } else {
            $inicio = $linhas.Count
            if ($inicio -gt 0 -and $linhas[$inicio - 1] -ne '') { $linhas.Add(''); $inicio++ }
        }
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
