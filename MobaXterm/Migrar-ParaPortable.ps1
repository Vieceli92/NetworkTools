<#
.SYNOPSIS
    Migra o MobaXterm instalado para o MobaXterm Portable (dentro do OneDrive) sem perder nada.

.DESCRIPTION
    Com o MobaXterm FECHADO, o script:
      1. Confere a pasta do portable e o .exe (e compara a versao com o instalado)
      2. Faz backup de todos os MobaXterm.ini encontrados (pasta _backup_migracao_...)
      3. Coloca o MobaXterm.ini ao lado do .exe do portable
         - se ja existir um ini la (ex.: Documentos sincronizado pelo OneDrive), ele e MANTIDO
         - senao copia o ini mais recente do Moba instalado (Documentos ou AppData)
      4. Ajusta os logs no ini: LogFolder=_MobaFolder_\Log (pasta Log ao lado do .exe),
         logs ligados, e troca caminhos absolutos antigos de log dentro das sessoes
      5. Copia plugins (.mxt3) do instalado
      6. Marca a pasta como "Sempre manter neste dispositivo" no OneDrive
      7. Atualiza o config.psd1 dos scripts e recria o atalho "MobaXterm (logs)"
    Rode o mesmo script no PC de casa: la ele so usa o ini que veio pelo OneDrive.

.EXAMPLE
    .\Migrar-ParaPortable.ps1 -WhatIf          # mostra o que faria, sem mudar nada
.EXAMPLE
    .\Migrar-ParaPortable.ps1 -TarefaAgendada   # migra e cria tambem a tarefa agendada dos logs
.EXAMPLE
    .\Migrar-ParaPortable.ps1 -IniOrigem 'C:\Users\eu\AppData\Roaming\MobaXterm\MobaXterm.ini'
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # Pasta onde esta o MobaXterm_Personal_XX.exe
    [string]$PastaPortable = $(if ($env:OneDrive) { Join-Path $env:OneDrive 'Documents\MobaXterm' } else { '' }),
    # Usa este ini em vez de escolher sozinho (substitui o que estiver na pasta do portable)
    [string]$IniOrigem,
    # Pasta de logs gravada no ini. _MobaFolder_ = pasta do .exe portable
    [string]$PastaLogsMoba = '_MobaFolder_\Log',
    # Copia tambem os logs antigos para a nova pasta de logs
    [switch]$CopiarLogsAntigos,
    [switch]$TarefaAgendada,
    [switch]$SemAtalho
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
$latin1 = [Text.Encoding]::GetEncoding(28591)
$agora = Get-Date

function Write-Passo([string]$Texto) { Write-Host "`n==> $Texto" -ForegroundColor Cyan }
function Write-Ok([string]$Texto)    { Write-Host "    [OK] $Texto" -ForegroundColor Green }
function Write-Aviso([string]$Texto) { Write-Host "    [!]  $Texto" -ForegroundColor Yellow }
function Write-Info([string]$Texto)  { Write-Host "         $Texto" }
function Get-CaminhoCheio([string]$Caminho) { [IO.Path]::GetFullPath($Caminho).TrimEnd('\', '/') }

function Set-IniValor {
    # Grava Chave=Valor numa secao (cria a chave/secao se nao existir). Retorna o valor antigo.
    param([Collections.Generic.List[string]]$Linhas, [string]$Secao, [string]$Chave, [string]$Valor)
    $ini = $Linhas.IndexOf("[$Secao]")
    if ($ini -lt 0) { $Linhas.Insert(0, "[$Secao]"); $Linhas.Insert(1, "$Chave=$Valor"); $Linhas.Insert(2, ''); return $null }
    $fim = $ini + 1
    while ($fim -lt $Linhas.Count -and $Linhas[$fim] -notmatch '^\[') { $fim++ }
    for ($i = $ini + 1; $i -lt $fim; $i++) {
        if ($Linhas[$i] -match ('^' + [regex]::Escape($Chave) + '=(.*)$')) {
            $antigo = $Matches[1]; $Linhas[$i] = "$Chave=$Valor"; return $antigo
        }
    }
    $Linhas.Insert($ini + 1, "$Chave=$Valor"); return $null
}

# ------------------------------------------------------------------ 1) checagens
Write-Passo 'Checando o ambiente'
if (Get-Process -Name 'MobaXterm*' -ErrorAction SilentlyContinue) {
    throw 'O MobaXterm esta aberto. Feche (inclusive o icone perto do relogio) e rode de novo.'
}
Write-Ok 'MobaXterm fechado'

if (-not $PastaPortable -or -not (Test-Path -LiteralPath $PastaPortable)) {
    throw "Pasta do portable nao encontrada: '$PastaPortable'. Informe com -PastaPortable."
}
$PastaPortable = Get-CaminhoCheio $PastaPortable
$exe = Get-ChildItem -LiteralPath $PastaPortable -Filter 'MobaXterm*.exe' -File |
    Where-Object { $_.Name -notmatch 'install|setup' } |
    Sort-Object { $_.VersionInfo.FileVersionRaw } -Descending | Select-Object -First 1
if (-not $exe) { throw "Nenhum MobaXterm*.exe em $PastaPortable. Extraia o zip do portable nessa pasta." }
Write-Ok "Portable: $($exe.FullName) (versao $($exe.VersionInfo.ProductVersion))"

$instalado = @("${env:ProgramFiles(x86)}\Mobatek\MobaXterm\MobaXterm.exe", "$env:ProgramFiles\Mobatek\MobaXterm\MobaXterm.exe") |
    Where-Object { $_ -and $_ -notlike '\Mobatek*' -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if ($instalado) {
    $vInst = (Get-Item -LiteralPath $instalado).VersionInfo.ProductVersion
    if ($vInst -ne $exe.VersionInfo.ProductVersion) {
        Write-Aviso "Versao diferente do instalado ($vInst). Funciona, mas o ideal e usar a mesma versao ou mais nova."
    } else { Write-Ok "Mesma versao do instalado ($vInst)" }
}

# ------------------------------------------------------------ 2) achar os ini
Write-Passo 'Procurando os MobaXterm.ini'
$iniDestino = Join-Path $PastaPortable 'MobaXterm.ini'
$locais = @(@([Environment]::GetFolderPath('MyDocuments'), $env:APPDATA) | Where-Object { $_ } | ForEach-Object { Join-Path (Join-Path $_ 'MobaXterm') 'MobaXterm.ini' })
if ($instalado) { $locais += Join-Path (Split-Path $instalado -Parent) 'MobaXterm.ini' }
$candidatos = @($locais) + @($iniDestino) | Where-Object { Test-Path -LiteralPath $_ } |
    ForEach-Object { Get-Item -LiteralPath $_ } | Sort-Object { $_.FullName.ToLower() } -Unique
foreach ($c in $candidatos) {
    $marca = if ((Get-CaminhoCheio $c.FullName) -eq (Get-CaminhoCheio $iniDestino)) { '  <- pasta do portable' } else { '' }
    Write-Info ('{0:dd/MM/yyyy HH:mm}  {1,8:N0} bytes  {2}{3}' -f $c.LastWriteTime, $c.Length, $c.FullName, $marca)
}

$origem = $null
if ($IniOrigem) {
    if (-not (Test-Path -LiteralPath $IniOrigem)) { throw "Nao achei $IniOrigem" }
    $origem = Get-Item -LiteralPath $IniOrigem
} elseif (Test-Path -LiteralPath $iniDestino) {
    Write-Ok 'Ja existe MobaXterm.ini na pasta do portable - ele sera mantido (e o que o OneDrive sincroniza).'
    $maisNovo = $candidatos | Where-Object { (Get-CaminhoCheio $_.FullName) -ne (Get-CaminhoCheio $iniDestino) -and
        $_.LastWriteTime -gt (Get-Item -LiteralPath $iniDestino).LastWriteTime.AddMinutes(1) } | Select-Object -First 1
    if ($maisNovo) { Write-Aviso "$($maisNovo.FullName) e mais recente. Se as sessoes certas estiverem nele, rode de novo com -IniOrigem '$($maisNovo.FullName)'." }
} else {
    $origem = $candidatos | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $origem) { throw 'Nenhum MobaXterm.ini encontrado. Abra o portable e use Settings > Configuration > General > Import configuration (.mobaconf).' }
}

$iniAppData = if ($env:APPDATA) { Join-Path (Join-Path $env:APPDATA 'MobaXterm') 'MobaXterm.ini' }
if ($iniAppData -and (Test-Path -LiteralPath $iniAppData) -and (Get-CaminhoCheio $iniAppData) -ne (Get-CaminhoCheio $iniDestino)) {
    Write-Aviso "Existe ${iniAppData} - e o ini que o Moba INSTALADO usa. Abra sempre pelo atalho 'MobaXterm (logs)',"
    Write-Info  'que passa o ini do OneDrive com -i. O atalho original do Moba abriria as configuracoes do AppData.'
}

# ------------------------------------------------------------------ 3) backup
Write-Passo 'Backup'
$pastaBackup = Join-Path $PastaPortable ('_backup_migracao_{0:yyyyMMdd_HHmmss}' -f $agora)
if ($PSCmdlet.ShouldProcess($pastaBackup, 'Copiar todos os MobaXterm.ini encontrados')) {
    New-Item -ItemType Directory -Path $pastaBackup -Force | Out-Null
    $n = 0
    foreach ($c in $candidatos) {
        $nome = '{0:D2}_{1}_MobaXterm.ini' -f ++$n, ((Split-Path (Split-Path $c.FullName -Parent) -Leaf) -replace '[^\w.-]', '_')
        Copy-Item -LiteralPath $c.FullName -Destination (Join-Path $pastaBackup $nome)
    }
    Write-Ok "$n arquivo(s) em $pastaBackup"
}

# --------------------------------------------------- 4) ini para a pasta do portable
if ($origem -and (Get-CaminhoCheio $origem.FullName) -ne (Get-CaminhoCheio $iniDestino)) {
    Write-Passo 'Copiando o MobaXterm.ini para o portable'
    if ($PSCmdlet.ShouldProcess($iniDestino, "Copiar de $($origem.FullName)")) {
        Copy-Item -LiteralPath $origem.FullName -Destination $iniDestino -Force
        Write-Ok "Copiado de $($origem.FullName)"
    }
}

# ------------------------------------------------------- 5) ajustar logs no ini
Write-Passo 'Ajustando logs e caminhos no ini'
$iniParaLer = if (Test-Path -LiteralPath $iniDestino) { $iniDestino } elseif ($origem) { $origem.FullName } else { $null }
if ($iniParaLer) {
    $linhas = [Collections.Generic.List[string]]::new([IO.File]::ReadAllLines($iniParaLer, $latin1))
    $mudou = $false

    if ((Get-MobaIniValor -Ini $iniParaLer -Secao 'Misc' -Chave 'PasswordsInRegistry') -eq '1') {
        Write-Aviso 'Senhas estao no REGISTRO (PasswordsInRegistry=1): elas nao vao junto para o outro PC.'
        Write-Info  'No Moba: Settings > General > MobaXterm passwords management > desmarque "store in registry".'
    }

    # pasta de logs antiga (valor bruto e resolvido pelo local antigo)
    $logAntigoBruto = Get-MobaIniValor -Ini $iniParaLer -Secao 'Misc' -Chave 'LogFolder'
    $logAntigoReal = if ($logAntigoBruto) {
        $iniRef = if ($origem) { $origem.FullName } else { $iniDestino }
        Resolve-MobaCaminho -Caminho $logAntigoBruto -Ini $iniRef -MobaExe $instalado
    }

    $anterior = Set-IniValor -Linhas $linhas -Secao 'Misc' -Chave 'LogFolder' -Valor $PastaLogsMoba
    if ($anterior -ne $PastaLogsMoba) { $mudou = $true; Write-Ok "LogFolder: '$anterior' -> '$PastaLogsMoba'" } else { Write-Ok "LogFolder ja era $PastaLogsMoba" }
    if ((Set-IniValor -Linhas $linhas -Secao 'Misc' -Chave 'LogTerminalActivity' -Valor '1') -ne '1') { $mudou = $true; Write-Ok 'Log de terminal ligado (LogTerminalActivity=1)' }

    # sessoes com caminho de log absoluto antigo -> _MobaFolder_\Log
    $absolutos = @($logAntigoBruto, $logAntigoReal) | Where-Object { $_ -and $_ -match '^[A-Za-z]:\\|^\\\\' } | Sort-Object -Unique
    $trocas = 0
    foreach ($abs in $absolutos) {
        $rx = [regex]::new([regex]::Escape($abs.TrimEnd('\')) + '(?=[%#\\]|$)', 'IgnoreCase')
        for ($i = 0; $i -lt $linhas.Count; $i++) {
            if ($linhas[$i] -notmatch '^LogFolder=' -and $rx.IsMatch($linhas[$i])) {
                $linhas[$i] = $rx.Replace($linhas[$i], $PastaLogsMoba.Replace('$', '$$')); $trocas++
            }
        }
    }
    if ($trocas) { $mudou = $true; Write-Ok "$trocas linha(s) de sessao apontando para '$($absolutos -join "' / '")' ajustadas para $PastaLogsMoba" }
    else { Write-Ok 'Sessoes ja usam caminho relativo de log (nada a trocar)' }

    foreach ($chave in 'HomeDir', 'SlashDir') {
        $v = Get-MobaIniValor -Ini $iniParaLer -Secao 'Misc' -Chave $chave
        if ($v -and $v -notmatch '^_') { Write-Aviso "$chave=$v e um caminho fixo deste PC. O padrao _AppDataDir_\MobaXterm\... funciona melhor em 2 PCs." }
    }

    if ($mudou -and (Test-Path -LiteralPath $iniDestino) -and $PSCmdlet.ShouldProcess($iniDestino, 'Gravar ajustes de log')) {
        [IO.File]::WriteAllText($iniDestino, (($linhas -join "`r`n") + "`r`n"), $latin1)
        Write-Ok 'MobaXterm.ini salvo'
    }

    $pastaLogNova = Resolve-MobaCaminho -Caminho $PastaLogsMoba -Ini $iniDestino -MobaExe $exe.FullName
    if ($PSCmdlet.ShouldProcess($pastaLogNova, 'Criar pasta de logs')) { New-Item -ItemType Directory -Path $pastaLogNova -Force | Out-Null }
    Write-Ok "Logs novos vao para: $pastaLogNova"

    if ($CopiarLogsAntigos -and $logAntigoReal -and (Test-Path -LiteralPath $logAntigoReal) -and
        (Get-CaminhoCheio $logAntigoReal) -ne (Get-CaminhoCheio $pastaLogNova)) {
        if ($PSCmdlet.ShouldProcess($logAntigoReal, "Copiar logs antigos para $pastaLogNova")) {
            Copy-Item -Path (Join-Path $logAntigoReal '*') -Destination $pastaLogNova -Recurse -Force
            Write-Ok "Logs antigos copiados de $logAntigoReal"
        }
    }
}

# -------------------------------------------------------------- 6) plugins
$pastasPlugins = @($(if ($instalado) { Split-Path $instalado -Parent }), $(if ($origem) { Split-Path $origem.FullName -Parent })) | Where-Object { $_ }
$plugins = $pastasPlugins | ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter '*.mxt3' -File -ErrorAction SilentlyContinue } |
    Where-Object { -not (Test-Path -LiteralPath (Join-Path $PastaPortable $_.Name)) }
if ($plugins) {
    Write-Passo 'Plugins'
    foreach ($p in $plugins) {
        if ($PSCmdlet.ShouldProcess($p.FullName, "Copiar para $PastaPortable")) { Copy-Item -LiteralPath $p.FullName -Destination $PastaPortable; Write-Ok $p.Name }
    }
}

# ------------------------------------------------------------- 7) OneDrive
Write-Passo 'OneDrive'
if ($PSCmdlet.ShouldProcess($PastaPortable, 'Marcar como "Sempre manter neste dispositivo"')) {
    try { & attrib.exe +P -U "$PastaPortable\*" /S /D 2>$null | Out-Null; & attrib.exe +P -U "$PastaPortable" 2>$null | Out-Null; Write-Ok 'Pasta marcada como "Sempre manter neste dispositivo"' }
    catch { Write-Aviso 'Nao consegui marcar. No Explorer: botao direito na pasta > Sempre manter neste dispositivo.' }
}
$conflitos = Get-ChildItem -LiteralPath $PastaPortable -Filter 'MobaXterm*.ini' -File | Where-Object Name -ne 'MobaXterm.ini'
foreach ($c in $conflitos) { Write-Aviso "Possivel conflito do OneDrive: $($c.Name) - compare com o MobaXterm.ini e apague o que sobrar." }

# ------------------------------------------------------- 8) config dos scripts
Write-Passo 'Configurando os scripts'
$arquivoCfg = Join-Path $PSScriptRoot 'config.psd1'
function ConvertTo-CaminhoCfg([string]$Caminho) {
    if ($env:OneDrive -and $Caminho.StartsWith($env:OneDrive, [StringComparison]::OrdinalIgnoreCase)) {
        return '%OneDrive%' + $Caminho.Substring($env:OneDrive.Length) }
    return $Caminho
}
$exeCfg = ConvertTo-CaminhoCfg $exe.FullName
# O ini e passado com "-i": se o .exe for da versao INSTALADA, ele ignoraria o ini ao
# lado dele e usaria %APPDATA%\MobaXterm\MobaXterm.ini (sem as sessoes/cores do OneDrive).
$iniCfg = ConvertTo-CaminhoCfg $iniDestino
$texto = Get-Content -LiteralPath $arquivoCfg -Raw
foreach ($par in @(@('MobaExe', $exeCfg), @('MobaIni', $iniCfg), @('PastaLogs', ''))) {
    $valor = $par[1]
    $texto = [regex]::Replace($texto, "(?m)^(\s*$($par[0])\s*=\s*)'[^']*'", { param($m) "$($m.Groups[1].Value)'$valor'" })
}
if ($PSCmdlet.ShouldProcess($arquivoCfg, "MobaExe = '$exeCfg'")) {
    Set-Content -LiteralPath $arquivoCfg -Value $texto -NoNewline -Encoding UTF8
    Write-Ok "config.psd1: MobaExe = '$exeCfg', MobaIni = '$iniCfg' (sempre abre com -i), PastaLogs = automatico"
}

if (-not $SemAtalho -and $PSCmdlet.ShouldProcess('Atalho "MobaXterm (logs)"', 'Recriar apontando para o portable')) {
    $argsInstalar = @{}
    if ($TarefaAgendada) { $argsInstalar.TarefaAgendada = $true }
    & (Join-Path $PSScriptRoot 'Instalar-MobaTools.ps1') @argsInstalar | ForEach-Object { Write-Ok $_ }
}

# ----------------------------------------------------------------- resumo
Write-Passo 'Pronto! Proximos passos'
Write-Info "1. Abra $($exe.Name) pelo atalho 'MobaXterm (logs)' e confira sessoes, master password, macros e cores."
Write-Info '   Se faltar algo: Settings > Configuration > General > Import configuration (.mobaconf).'
Write-Info '2. Desafixe o atalho do Moba instalado da barra de tarefas e fixe o "MobaXterm (logs)".'
Write-Info '3. Use alguns dias; depois desinstale o Moba instalado (o backup fica em:'
Write-Info "   $pastaBackup)"
$ssh = if ($env:APPDATA) { Join-Path $env:APPDATA 'MobaXterm\home\.ssh' }
if ($ssh -and (Test-Path -LiteralPath $ssh)) {
    Write-Info "4. Voce tem chaves SSH em $ssh - copie essa pasta para o mesmo lugar no PC de casa (ela nao vai pelo OneDrive)."
}
Write-Info 'No PC de casa: espere o OneDrive sincronizar e rode este mesmo script (ele usa o ini que veio pelo OneDrive).'
Write-Host "`n    NUNCA deixe o MobaXterm aberto nos dois PCs ao mesmo tempo." -ForegroundColor Yellow
