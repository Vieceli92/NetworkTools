; ============================================================================
;  Moba Anti-Idle  -  "anti-idle" estilo SecureCRT para o MobaXterm
;  Requer AutoHotkey v2 (https://www.autohotkey.com)
;
;  De tempos em tempos manda Espaco+Backspace para o terminal do MobaXterm,
;  assim o exec-timeout (Cisco), idle-timeout (Huawei) e idle-timeout (Juniper)
;  nao derrubam a sessao. Nao apaga nada que voce ja tenha digitado.
;
;  LIMITACAO: o Windows so deixa mandar teclas para a ABA ATIVA de cada janela
;  do Moba. Para manter varias sessoes vivas, destaque as abas importantes
;  (botao "Detach" / arrastar a aba para fora): cada janela destacada recebe
;  o anti-idle.
;
;  Uso:  MobaAntiIdle.ahk [intervalo_em_segundos]      (padrao 240 = 4 min)
;  Atalho: Ctrl+Alt+Shift+A liga/pausa.  Menu no icone da bandeja.
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetTitleMatchMode "RegEx"      ; necessario para "ahk_exe i)^MobaXterm.*\.exe$" (portable ou instalado)

; ---------------------------------------------------------------- ajustes
IntervaloSeg   := 240                    ; menor que o timeout do equipamento (ex.: 5 min -> 240 s)
Teclas         := "{Space}{Backspace}"   ; o que e enviado (ex.: "{Ctrl down}@{Ctrl up}" = NUL)
PausaDigitando := 15                     ; nao envia se voce digitou no Moba ha menos de N s
; Classes das janelas do Moba que recebem o anti-idle (regex). Use o menu
; "Listar janelas do Moba" para ver a classe da janela principal e das abas destacadas.
ClassesAlvo    := "i)^TMobaXterm"
; Titulos que NUNCA recebem teclas (editor, dialogos, configuracoes...)
TitulosIgnorar := "i)MobaTextEditor|MobaTextDiff|Settings|Configuration|Session settings|Macro|Password|Warning|Confirm|Question|Error"
SairSemMoba    := true                   ; fecha sozinho quando nao houver Moba aberto
; -------------------------------------------------------------------------

if A_Args.Length >= 1 && IsInteger(A_Args[1])
    IntervaloSeg := Integer(A_Args[1])

Ativo := true
UltimoEnvio := "nunca"
AvisouSemJanela := false

A_IconTip := "Moba Anti-Idle - a cada " IntervaloSeg " s"
A_TrayMenu.Add()
A_TrayMenu.Add("Pausar / retomar  (Ctrl+Alt+Shift+A)", AlternarPausa)
A_TrayMenu.Add("Enviar agora", (*) => EnviarAntiIdle(true))
A_TrayMenu.Add("Listar janelas do Moba", ListarJanelas)
A_TrayMenu.Add("Status", MostrarStatus)
A_TrayMenu.Default := "Status"

SetTimer EnviarAntiIdle, IntervaloSeg * 1000
TrayTip "Anti-idle ligado: Espaco+Backspace a cada " IntervaloSeg " s", "Moba Anti-Idle"

^!+a:: AlternarPausa()

AlternarPausa(*) {
    global Ativo
    Ativo := !Ativo
    A_IconTip := "Moba Anti-Idle - " (Ativo ? "a cada " IntervaloSeg " s" : "PAUSADO")
    TrayTip Ativo ? "Ligado" : "Pausado", "Moba Anti-Idle"
}

JanelasMoba() {
    lista := []
    for hwnd in WinGetList("ahk_exe i)^MobaXterm.*\.exe$") {
        try {
            if !DllCall("IsWindowVisible", "ptr", hwnd)
                continue
            classe := WinGetClass(hwnd), titulo := WinGetTitle(hwnd)
            WinGetPos(, , &w, &h, hwnd)
            if !RegExMatch(classe, ClassesAlvo) || RegExMatch(titulo, TitulosIgnorar) || w < 300 || h < 150
                continue
            if !DllCall("IsWindowEnabled", "ptr", hwnd)   ; tem um dialogo aberto por cima
                continue
            lista.Push(hwnd)
        }
    }
    return lista
}

EnviarAntiIdle(forcar := false) {
    global UltimoEnvio, AvisouSemJanela
    if !Ativo && !forcar
        return
    if SairSemMoba && !WinExist("ahk_exe i)^MobaXterm.*\.exe$")
        ExitApp
    janelas := JanelasMoba()
    if janelas.Length = 0 {
        if !AvisouSemJanela && WinExist("ahk_exe i)^MobaXterm.*\.exe$") {
            AvisouSemJanela := true
            TrayTip "Nenhuma janela do Moba reconhecida. Use 'Listar janelas do Moba' e ajuste ClassesAlvo.", "Moba Anti-Idle"
        }
        return
    }
    enviados := 0
    for hwnd in janelas {
        ; voce esta digitando nessa janela agora -> ela ja esta viva
        if !forcar && WinActive(hwnd) && A_TimeIdleKeyboard < PausaDigitando * 1000
            continue
        try {
            ctrl := ControlGetFocus(hwnd)       ; o terminal da aba ativa
            if ctrl
                ControlSend Teclas, ctrl
            else
                ControlSend Teclas, , hwnd
            enviados++
        }
    }
    UltimoEnvio := FormatTime(, "HH:mm:ss") " (" enviados " janela(s))"
}

ListarJanelas(*) {
    txt := ""
    for hwnd in WinGetList("ahk_exe i)^MobaXterm.*\.exe$") {
        try {
            if !DllCall("IsWindowVisible", "ptr", hwnd)
                continue
            WinGetPos(, , &w, &h, hwnd)
            alvo := RegExMatch(WinGetClass(hwnd), ClassesAlvo) && !RegExMatch(WinGetTitle(hwnd), TitulosIgnorar) && w >= 300 && h >= 150
            txt .= (alvo ? "[X] " : "[ ] ") WinGetClass(hwnd) "  |  " WinGetTitle(hwnd) "  (" w "x" h ")`n"
        }
    }
    MsgBox txt = "" ? "Nenhuma janela do MobaXterm aberta." : "[X] = recebe o anti-idle`n`n" txt
        . "`nPara incluir outra classe, edite ClassesAlvo no inicio do script (ex.: `"i)^TMobaXterm|^TOutraClasse`").",
        "Moba Anti-Idle - janelas"
}

MostrarStatus(*) {
    MsgBox "Estado: " (Ativo ? "ligado" : "PAUSADO")
        . "`nIntervalo: " IntervaloSeg " s"
        . "`nTeclas: " Teclas
        . "`nUltimo envio: " UltimoEnvio
        . "`nJanelas alvo agora: " JanelasMoba().Length, "Moba Anti-Idle"
}
