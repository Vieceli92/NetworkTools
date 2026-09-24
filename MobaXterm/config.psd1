# ==========================================================================
#  Configuracao dos scripts MobaXterm (edite so este arquivo)
#  Pode usar variaveis de ambiente no formato %NOME% (ex.: %USERPROFILE%, %OneDrive%)
# ==========================================================================
@{
    # Caminho do executavel do MobaXterm
    #   Instalado : C:\Program Files (x86)\Mobatek\MobaXterm\MobaXterm.exe
    #   Portable  : onde voce extraiu o MobaXterm_Personal_XX.exe
    #               (ex.: '%OneDrive%\MobaXterm\MobaXterm_Personal_26.4.exe' - ver README)
    MobaExe            = 'C:\Program Files (x86)\Mobatek\MobaXterm\MobaXterm.exe'

    # MobaXterm.ini a usar. Vazio = padrao do Moba (Documentos\MobaXterm).
    # Para sincronizar pelo OneDrive, aponte para o ini dentro do OneDrive:
    #   '%OneDrive%\MobaXterm\MobaXterm.ini'
    MobaIni            = ''

    # Pasta onde o MobaXterm grava os logs
    # (Settings > Configuration > Terminal > "Log terminal output to the following directory")
    # Vazio = detecta sozinho lendo "LogFolder=" do MobaXterm.ini (ex.: _MobaFolder_\Log)
    PastaLogs          = ''

    # Pasta onde os logs organizados vao ficar. Vazio = dentro da propria PastaLogs.
    # Ex.: '%OneDrive%\MobaXterm\Logs' para ter os logs em casa tambem.
    PastaDestino       = ''

    # Extensoes consideradas log
    Extensoes          = @('*.log', '*.txt')

    # Arquivos alterados ha menos de N minutos sao ignorados (sessao ainda aberta)
    MinutosIgnorar     = 5

    # Compacta em .zip as pastas de meses com mais de N meses. 0 = desativado
    CompactarAposMeses = 0

    # Apaga logs (e zips) com mais de N dias. 0 = nunca apaga
    ApagarAposDias     = 0

    # Organiza novamente quando o MobaXterm for fechado (so pelo atalho do launcher)
    OrganizarAoFechar  = $true
}
