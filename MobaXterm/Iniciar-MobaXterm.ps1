<#
.SYNOPSIS
    Launcher do MobaXterm: abre o Moba, sobe o anti-idle e organiza os logs.

.DESCRIPTION
    Use este script no lugar do atalho normal do MobaXterm (o Instalar-MobaTools.ps1
    cria o atalho "MobaXterm (logs)" para voce). Ele:
      1. Abre o MobaXterm (com -i <ini do OneDrive>, se configurado em config.psd1)
      2. Sobe o anti-idle (se AntiIdle = $true e o AutoHotkey existir)
      3. Organiza os logs (Organizar-LogsMoba.ps1) - depois de abrir, para nao atrasar o Moba
      4. Se OrganizarAoFechar = $true, espera o Moba fechar e organiza de novo
    Como o atalho roda escondido, qualquer erro aparece numa janela de aviso e fica em
    %TEMP%\MobaTools\iniciar.log.
    Parametros extras sao repassados ao MobaXterm (ex.: -bookmark "Switch-Core").
#>
param([Parameter(ValueFromRemainingArguments)][string[]]$ArgsMoba)

$ErrorActionPreference = 'Stop'
$pastaLog = Join-Path ([IO.Path]::GetTempPath()) 'MobaTools'
$arqLog = Join-Path $pastaLog 'iniciar.log'

function Write-Log([string]$Msg) {
    try {
        New-Item -ItemType Directory -Path $pastaLog -Force | Out-Null
        Add-Content -LiteralPath $arqLog -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Msg)
    } catch { }
}

function Show-Erro([string]$Msg) {
    Write-Log "ERRO: $Msg"
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show("$Msg`n`nDetalhes em: $arqLog`nPara conferir tudo: Diagnostico.cmd", 'MobaXterm (logs)', 'OK', 'Error')
    } catch { Write-Host $Msg -ForegroundColor Red }
}

try {
    . (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')
    $cfg = Get-MobaConfig
    $organizador = Join-Path $PSScriptRoot 'Organizar-LogsMoba.ps1'
    Write-Log "Inicio. MobaExe='$($cfg.MobaExe)' MobaIni='$($cfg.MobaIni)'"

    # ------------------------------------------------------------ 1) abrir o Moba
    if (-not $cfg.MobaExe -or -not (Test-Path -LiteralPath $cfg.MobaExe)) {
        throw "MobaXterm nao encontrado em '$($cfg.MobaExe)'.`nAjuste MobaExe no config.psd1 (ou rode Migrar-ParaPortable.ps1)."
    }
    $argumentos = @()
    if ($cfg.MobaIni) {
        if (-not (Test-Path -LiteralPath $cfg.MobaIni)) {
            throw "MobaXterm.ini nao encontrado em '$($cfg.MobaIni)'.`nO OneDrive ja sincronizou? Ajuste MobaIni no config.psd1."
        }
        $argumentos += '-i', ('"{0}"' -f $cfg.MobaIni)
    }
    # Start-Process nao coloca aspas sozinho: "NE BNG" viraria dois argumentos
    if ($ArgsMoba) { $argumentos += $ArgsMoba | ForEach-Object { if ($_ -match '\s' -and $_ -notmatch '^".*"$') { '"{0}"' -f $_ } else { $_ } } }

    $inicio = @{ FilePath = $cfg.MobaExe; PassThru = $true; WorkingDirectory = (Split-Path $cfg.MobaExe -Parent) }
    if ($argumentos) { $inicio.ArgumentList = $argumentos }
    $proc = Start-Process @inicio
    Write-Log "MobaXterm iniciado (PID $($proc.Id)) $($argumentos -join ' ')"

    # ------------------------------------------------------------ 2) anti-idle
    if ($cfg.AntiIdle) {
        try {
            $ahk = Join-Path $PSScriptRoot 'AntiIdle\MobaAntiIdle.ahk'
            $motor = @(
                (Join-Path $PSScriptRoot 'AntiIdle\AutoHotkey64.exe'),
                $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe' }),
                $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey.exe' }),
                $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe' })
            ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
            if ($motor) {
                $seg = if ($cfg.AntiIdleSegundos) { $cfg.AntiIdleSegundos } else { 240 }
                Start-Process -FilePath $motor -ArgumentList ('"{0}"' -f $ahk), $seg
                Write-Log "Anti-idle iniciado ($motor, $seg s)"
            } else {
                Write-Log 'Anti-idle ligado, mas o AutoHotkey v2 nao foi encontrado (rode Instalar AntiIdle.cmd).'
            }
        } catch { Write-Log "Falha no anti-idle: $_" }
    }

    # ------------------------------------------------------------ 3) organizar logs (depois de abrir)
    try { & $organizador | ForEach-Object { Write-Log $_ } } catch { Write-Log "Falha ao organizar logs: $_" }

    # ------------------------------------------------------------ 4) organizar de novo ao fechar
    if ($cfg.OrganizarAoFechar) {
        $proc.WaitForExit()
        Write-Log 'MobaXterm fechado'
        try { & $organizador | ForEach-Object { Write-Log $_ } } catch { Write-Log "Falha ao organizar logs: $_" }
    }
} catch {
    Show-Erro $_.Exception.Message
}
