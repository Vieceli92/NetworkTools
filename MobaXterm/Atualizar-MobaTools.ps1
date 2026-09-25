<#
.SYNOPSIS
    Atualiza a pasta dos scripts com a versao mais nova do GitHub.

.DESCRIPTION
    - Baixa o zip do repositorio (branch configurada abaixo) e copia a pasta MobaXterm
      por cima desta pasta.
    - PRESERVA o seu config.psd1. Opcoes novas que aparecerem na versao nova sao
      acrescentadas nele com o valor padrao (e avisadas na tela).
    - Nao mexe no AutoHotkey64.exe (pasta AntiIdle), logs nem backups.
    - Desbloqueia os arquivos (Unblock-File) no fim.
    - Guarda a versao instalada em versao.txt e nao baixa de novo se ja estiver atualizado
      (use -Forcar para baixar mesmo assim).

.EXAMPLE
    .\Atualizar-MobaTools.ps1
.EXAMPLE
    .\Atualizar-MobaTools.ps1 -Branch main -Forcar
#>
param(
    [string]$Repositorio = 'Vieceli92/NetworkTools',
    [string]$Branch = 'claude/compassionate-edison-876c18',
    [switch]$Forcar
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$destino = $PSScriptRoot
$arqVersao = Join-Path $destino 'versao.txt'
$preservar = @('config.psd1', 'versao.txt')     # nunca sobrescritos

function Write-Ok([string]$T) { Write-Host "  [OK] $T" -ForegroundColor Green }
function Write-Aviso([string]$T) { Write-Host "  [!]  $T" -ForegroundColor Yellow }

Write-Host "`nAtualizando $destino" -ForegroundColor Cyan
Write-Host "  origem: github.com/$Repositorio (branch $Branch)"

# ---------------------------------------------------------------- versao remota
$remota = $null
try {
    $api = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$Repositorio/commits/$([uri]::EscapeDataString($Branch))" -Headers @{ 'User-Agent' = 'MobaTools' }
    $remota = [pscustomobject]@{ Sha = $api.sha; Data = [datetime]$api.commit.author.date; Mensagem = ($api.commit.message -split "`n")[0] }
    Write-Host ("  versao no GitHub: {0} ({1:dd/MM/yyyy HH:mm}) {2}" -f $remota.Sha.Substring(0, 7), $remota.Data.ToLocalTime(), $remota.Mensagem)
} catch {
    Write-Aviso 'Nao consegui consultar a versao no GitHub; vou baixar mesmo assim.'
}
$local = if (Test-Path -LiteralPath $arqVersao) { (Get-Content -LiteralPath $arqVersao -TotalCount 1).Trim() } else { '' }
if ($remota -and $local -eq $remota.Sha -and -not $Forcar) {
    Write-Ok 'Ja esta na versao mais nova. (Use -Forcar para baixar de novo.)'
    return
}

# ---------------------------------------------------------------- download
$temp = Join-Path ([IO.Path]::GetTempPath()) ('mobatools_' + [guid]::NewGuid().ToString('N'))
$zip = "$temp.zip"
try {
    $url = "https://codeload.github.com/$Repositorio/zip/refs/heads/$Branch"
    try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip }
    catch {
        $codigo = try { [int]$_.Exception.Response.StatusCode } catch { 0 }
        if ($codigo -eq 404) {
            throw "Nao encontrado (404). A branch '$Branch' pode ter sido renomeada/mesclada (tente -Branch main) ou o repositorio e privado (baixe o zip pelo GitHub logado e extraia por cima)."
        }
        throw
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $temp -Force
    $origem = Get-ChildItem -LiteralPath $temp -Directory | ForEach-Object { Join-Path $_.FullName 'MobaXterm' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $origem) { throw 'Pasta MobaXterm nao encontrada no zip.' }

    # ------------------------------------------------------------ copiar arquivos
    $n = 0
    foreach ($f in Get-ChildItem -LiteralPath $origem -Recurse -File) {
        $rel = $f.FullName.Substring($origem.Length).TrimStart('\', '/')
        if ($preservar -contains $rel) { continue }
        $alvo = Join-Path $destino $rel
        New-Item -ItemType Directory -Path (Split-Path $alvo -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination $alvo -Force
        $n++
    }
    Write-Ok "$n arquivo(s) atualizados"

    # ------------------------------------------------------------ config.psd1: preserva e acrescenta opcoes novas
    $cfgNovo = Join-Path $origem 'config.psd1'
    $cfgMeu = Join-Path $destino 'config.psd1'
    if (-not (Test-Path -LiteralPath $cfgMeu)) {
        Copy-Item -LiteralPath $cfgNovo -Destination $cfgMeu
        Write-Ok 'config.psd1 criado'
    } else {
        $chavesMinhas = (Import-PowerShellDataFile -LiteralPath $cfgMeu).Keys
        $linhasNovas = Get-Content -LiteralPath $cfgNovo
        $faltando = @((Import-PowerShellDataFile -LiteralPath $cfgNovo).Keys | Where-Object { $chavesMinhas -notcontains $_ })
        if ($faltando.Count) {
            $bloco = @()
            foreach ($k in $faltando) {
                $i = [array]::FindIndex([string[]]$linhasNovas, [Predicate[string]]{ param($l) $l -match "^\s*$k\s*=" })
                if ($i -lt 0) { continue }
                $ini = $i
                while ($ini -gt 0 -and $linhasNovas[$ini - 1] -match '^\s*#') { $ini-- }   # leva os comentarios junto
                $bloco += '' ; $bloco += $linhasNovas[$ini..$i]
            }
            $meu = [Collections.Generic.List[string]](Get-Content -LiteralPath $cfgMeu)
            $fecha = $meu.FindLastIndex([Predicate[string]]{ param($l) $l -match '^\s*\}\s*$' })
            if ($fecha -ge 0) {
                Copy-Item -LiteralPath $cfgMeu -Destination ('{0}.bak_{1:yyyyMMdd_HHmmss}' -f $cfgMeu, (Get-Date))
                $meu.InsertRange($fecha, [string[]]$bloco)
                Set-Content -LiteralPath $cfgMeu -Value $meu -Encoding UTF8
                Write-Ok "config.psd1 mantido; opcoes novas acrescentadas: $($faltando -join ', ')"
            } else { Write-Aviso "Opcoes novas nao acrescentadas (config.psd1 fora do padrao): $($faltando -join ', ')" }
        } else { Write-Ok 'config.psd1 mantido (sem opcoes novas)' }
    }

    if ($remota) { Set-Content -LiteralPath $arqVersao -Value $remota.Sha, ('{0:yyyy-MM-dd HH:mm} {1}' -f $remota.Data.ToLocalTime(), $remota.Mensagem) }
    try { Get-ChildItem -LiteralPath $destino -Recurse -File | Unblock-File; Write-Ok 'Arquivos desbloqueados' }
    catch { Write-Aviso "Nao consegui desbloquear os arquivos: $($_.Exception.Message)" }
    Write-Host "`nPronto! Se o MobaXterm ou a janela de pesquisa estiverem abertos, feche e abra de novo." -ForegroundColor Cyan
    Write-Host 'Se mudaram as cores (Syntax-Redes.ini), rode tambem o Instalar-SyntaxRedes.ps1 com o Moba fechado.'
} catch {
    Write-Host "`nNao foi possivel atualizar: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
