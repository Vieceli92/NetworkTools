<#
.SYNOPSIS
    Sincroniza as sessoes do MobaXterm (MobaXterm.ini) entre PCs usando o OneDrive.

.DESCRIPTION
    As sessoes, pastas de sessoes, macros e configuracoes ficam todas no MobaXterm.ini.
    Este script coloca esse arquivo no OneDrive e faz o MobaXterm usar ele.

    PASSO 1 - no PC do TRABALHO (onde estao as sessoes):
        .\Configurar-SyncOneDrive.ps1 -Modo Enviar
    PASSO 2 - espere o OneDrive sincronizar e, no PC de CASA:
        .\Configurar-SyncOneDrive.ps1 -Modo Receber

    Metodos:
      -Metodo Launcher (padrao): grava o caminho em config.psd1 e o Moba e aberto com
                                 "MobaXterm.exe -i <ini do OneDrive>" pelo atalho do launcher.
      -Metodo Symlink          : troca o MobaXterm.ini local por um link simbolico para o
                                 OneDrive (funciona com qualquer atalho do Moba; precisa
                                 PowerShell como Administrador ou Modo de Desenvolvedor).

    Um backup do ini local e sempre criado antes (MobaXterm.ini.bak_AAAAMMDD_HHMMSS).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Enviar', 'Receber')][string]$Modo,
    [ValidateSet('Launcher', 'Symlink')][string]$Metodo = 'Launcher',
    [string]$IniLocal,
    [string]$PastaOneDrive = (Join-Path $env:OneDrive 'MobaXterm'),
    [switch]$Forcar
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
$cfg = Get-MobaConfig
$arquivoCfg = Join-Path $PSScriptRoot 'config.psd1'

if (-not $env:OneDrive) { throw 'Variavel %OneDrive% nao encontrada. O OneDrive esta instalado/logado? Use -PastaOneDrive.' }
if (Get-Process -Name 'MobaXterm*' -ErrorAction SilentlyContinue) { throw 'Feche o MobaXterm antes (ele regrava o ini ao sair).' }

if (-not $IniLocal) { $IniLocal = Find-MobaIni -MobaExe $cfg.MobaExe }
$IniOneDrive = Join-Path $PastaOneDrive 'MobaXterm.ini'
New-Item -ItemType Directory -Path $PastaOneDrive -Force | Out-Null

if ($Modo -eq 'Enviar' -and (Test-Path -LiteralPath $IniOneDrive) -and -not $Forcar) {
    throw "Ja existe $IniOneDrive (outro PC ja enviou?). Use -Modo Receber, ou -Forcar para sobrescrever."
}

if ($IniLocal -and (Test-Path -LiteralPath $IniLocal) -and -not (Get-Item -LiteralPath $IniLocal).LinkType) {
    $bak = '{0}.bak_{1:yyyyMMdd_HHmmss_fff}' -f $IniLocal, (Get-Date)
    if ($PSCmdlet.ShouldProcess($IniLocal, "Backup em $bak")) { Copy-Item -LiteralPath $IniLocal -Destination $bak }
    Write-Output "Backup do ini local: $bak"
}

switch ($Modo) {
    'Enviar' {
        if (-not $IniLocal -or -not (Test-Path -LiteralPath $IniLocal)) { throw 'MobaXterm.ini local nao encontrado. Informe com -IniLocal.' }
        if ($PSCmdlet.ShouldProcess($IniOneDrive, 'Copiar ini local para o OneDrive')) {
            Copy-Item -LiteralPath $IniLocal -Destination $IniOneDrive -Force
        }
        Write-Output "Ini enviado para o OneDrive: $IniOneDrive"
    }
    'Receber' {
        if (-not (Test-Path -LiteralPath $IniOneDrive)) { throw "Nao achei $IniOneDrive. Rode -Modo Enviar no outro PC e espere o OneDrive sincronizar." }
        # Garante que o arquivo esta baixado (nao so "disponivel online")
        try { attrib.exe +P "$IniOneDrive" 2>$null } catch { }
    }
}

if ($Metodo -eq 'Symlink') {
    if (-not $IniLocal) { $IniLocal = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'MobaXterm\MobaXterm.ini' }
    if ($PSCmdlet.ShouldProcess($IniLocal, "Criar link simbolico -> $IniOneDrive")) {
        New-Item -ItemType Directory -Path (Split-Path $IniLocal -Parent) -Force | Out-Null
        if (Test-Path -LiteralPath $IniLocal) { Remove-Item -LiteralPath $IniLocal -Force }
        New-Item -ItemType SymbolicLink -Path $IniLocal -Target $IniOneDrive | Out-Null
    }
    Write-Output "Link criado: $IniLocal -> $IniOneDrive"
} else {
    $texto = Get-Content -LiteralPath $arquivoCfg -Raw
    $valor = $IniOneDrive.Replace($env:OneDrive, '%OneDrive%')
    $novo  = [regex]::Replace($texto, "(?m)^(\s*MobaIni\s*=\s*)'.*'", { param($m) "$($m.Groups[1].Value)'$valor'" })
    if ($PSCmdlet.ShouldProcess($arquivoCfg, "MobaIni = '$valor'")) { Set-Content -LiteralPath $arquivoCfg -Value $novo -NoNewline -Encoding UTF8 }
    Write-Output "config.psd1 atualizado: MobaIni = '$valor'. Abra o Moba pelo atalho 'MobaXterm (logs)'."
}

Write-Output ''
Write-Output 'IMPORTANTE: nao deixe o MobaXterm aberto nos dois PCs ao mesmo tempo - ele grava o ini'
Write-Output 'ao fechar e o ultimo a fechar vence (o OneDrive pode criar "MobaXterm-NOMEPC.ini" em conflito).'
