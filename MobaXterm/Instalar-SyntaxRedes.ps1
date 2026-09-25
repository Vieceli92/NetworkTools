<#
.SYNOPSIS
    Instala os perfis de cores de redes (Cisco/Huawei/Juniper) no MobaXterm.ini.

.DESCRIPTION
    O MobaXterm so mostra 3 perfis personalizados ([CustomSyntax1] a [CustomSyntax3]),
    que ja vem ocupados com exemplos. Por isso os perfis de Syntax-Redes.ini SUBSTITUEM:
      - slot 3 ("Custom: Cisco (network)")  -> "Custom: Redes (Cisco/Huawei/Juniper)"  (completo)
      - slot 2 ("Custom: Unix shell")       -> "Custom: Redes compacto"
    O slot 1 ("Custom: OK/warning/error keywords") fica como esta. Use -Slots para escolher
    outros (ex.: -Slots 1,3). Secoes antigas instaladas em slots invisiveis (4, 5...) sao removidas.
    O MobaXterm precisa estar FECHADO. Um backup do ini e criado antes.

    Depois: Settings > Configuration > Terminal > Syntax highlighting, ou em cada
    sessao: Edit session > Terminal settings > Syntax highlighting.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Ini,
    # Slots (1 a 3) usados, na ordem dos perfis do Syntax-Redes.ini
    [ValidateRange(1, 3)][int[]]$Slots = @(3, 2)
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
$nomesNossos = $perfis | ForEach-Object { ($_ | Where-Object { $_ -like 'Name=*' }) -replace '^Name=' }
if ($Slots.Count -lt $perfis.Count) { throw "Informe $($perfis.Count) slots em -Slots (um por perfil)." }

# Limpa instalacoes antigas nos slots que o Moba nao mostra (4, 5, ...)
for ($i = 0; $i -lt $linhas.Count; $i++) {
    if ($linhas[$i] -match '^\[CustomSyntax(\d+)\]$' -and [int]$Matches[1] -gt 3) {
        $fim = $i + 1
        while ($fim -lt $linhas.Count -and $linhas[$fim] -notmatch '^\[') { $fim++ }
        $nomeSecao = ($linhas.GetRange($i, $fim - $i) | Where-Object { $_ -like 'Name=*' }) -replace '^Name='
        if ($nomesNossos -contains $nomeSecao) {
            $resumo += "  removido $($linhas[$i]) $nomeSecao (slot invisivel no Moba)"
            $linhas.RemoveRange($i, $fim - $i); $i--
        }
    }
}

$n = 0
foreach ($perfil in $perfis) {
    $nome = ($perfil | Where-Object { $_ -like 'Name=*' }) -replace '^Name='
    $alvo = $Slots[$n++]

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
