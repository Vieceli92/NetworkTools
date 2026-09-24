# Funcoes compartilhadas pelos scripts MobaXterm. Nao execute direto.

function Expand-Caminho([string]$Caminho) {
    if ([string]::IsNullOrWhiteSpace($Caminho)) { return '' }
    return [Environment]::ExpandEnvironmentVariables($Caminho)
}

function Get-MobaConfig {
    param([string]$Arquivo = (Join-Path $PSScriptRoot 'config.psd1'))
    if (-not (Test-Path -LiteralPath $Arquivo)) { throw "Arquivo de configuracao nao encontrado: $Arquivo" }
    $cfg = Import-PowerShellDataFile -LiteralPath $Arquivo
    foreach ($k in 'MobaExe', 'MobaIni', 'PastaLogs', 'PastaDestino') { $cfg[$k] = Expand-Caminho $cfg[$k] }
    return $cfg
}

function Find-MobaIni {
    # Procura o MobaXterm.ini nos locais padrao (instalado e portable)
    param([string]$MobaExe)
    # Portable (ini ao lado do exe) tem prioridade, como no proprio MobaXterm
    $candidatos = @()
    if ($MobaExe) { $candidatos += (Join-Path (Split-Path $MobaExe -Parent) 'MobaXterm.ini') }
    foreach ($base in [Environment]::GetFolderPath('MyDocuments'), $env:APPDATA) {
        if ($base) { $candidatos += (Join-Path $base 'MobaXterm\MobaXterm.ini') }
    }
    return $candidatos | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

function Get-MobaIniValor {
    # Le uma chave de uma secao do MobaXterm.ini (o ini do Moba e ANSI/Latin-1)
    param([string]$Ini, [string]$Secao, [string]$Chave)
    $dentro = $false
    foreach ($linha in [IO.File]::ReadLines($Ini, [Text.Encoding]::GetEncoding(28591))) {
        if ($linha -match '^\s*\[(.+)\]\s*$') { $dentro = ($Matches[1] -eq $Secao); continue }
        if ($dentro -and $linha -match ('^\s*' + [regex]::Escape($Chave) + '\s*=(.*)$')) { return $Matches[1].Trim() }
    }
}

function Resolve-MobaCaminho {
    # Troca as variaveis do Moba (_MobaFolder_, _AppDataDir_, ...) por caminhos reais
    param([string]$Caminho, [string]$Ini, [string]$MobaExe)
    if (-not $Caminho) { return '' }
    $pastaIni = if ($Ini) { Split-Path $Ini -Parent } else { '' }
    $pastaExe = if ($MobaExe) { Split-Path $MobaExe -Parent } else { '' }
    $mapa = [ordered]@{
        '_AppDataDir_'   = $env:APPDATA
        '_MyDocuments_'  = [Environment]::GetFolderPath('MyDocuments')
        '_ProfileDir_'   = $env:USERPROFILE
        '_Desktop_'      = [Environment]::GetFolderPath('Desktop')
        '_CurrentDrive_' = if ($pastaExe) { [IO.Path]::GetPathRoot($pastaExe).TrimEnd('\', '/') } else { $env:SystemDrive }
    }
    foreach ($k in $mapa.Keys) { $Caminho = $Caminho.Replace($k, $mapa[$k]) }
    if ($Caminho -like '*_MobaFolder_*') {
        # _MobaFolder_ = pasta do MobaXterm (a do ini na versao instalada, a do exe na portable)
        foreach ($base in @($pastaIni, $pastaExe) | Where-Object { $_ }) {
            $teste = $Caminho.Replace('_MobaFolder_', $base)
            if (Test-Path -LiteralPath $teste) { return $teste }
        }
        $Caminho = $Caminho.Replace('_MobaFolder_', $(if ($pastaIni) { $pastaIni } else { $pastaExe }))
    }
    return $Caminho
}

function Get-MobaPastaLogs {
    # Descobre a pasta de logs lendo LogFolder= do MobaXterm.ini
    param($Cfg)
    $ini = if ($Cfg.MobaIni -and (Test-Path -LiteralPath $Cfg.MobaIni)) { $Cfg.MobaIni } else { Find-MobaIni -MobaExe $Cfg.MobaExe }
    if (-not $ini) { throw 'Nao achei o MobaXterm.ini para descobrir a pasta de logs. Preencha PastaLogs no config.psd1.' }
    $valor = Get-MobaIniValor -Ini $ini -Secao 'Misc' -Chave 'LogFolder'
    if (-not $valor) { throw "LogFolder nao definido em $ini. Ative o log em Settings > Terminal ou preencha PastaLogs no config.psd1." }
    return Resolve-MobaCaminho -Caminho $valor -Ini $ini -MobaExe $Cfg.MobaExe
}
