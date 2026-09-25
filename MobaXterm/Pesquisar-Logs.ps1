<#
.SYNOPSIS
    Janela para pesquisar e comparar os logs do MobaXterm (hostname, IP, comando, qualquer texto).

.DESCRIPTION
    PESQUISAR
    - Procura no NOME do arquivo e/ou DENTRO do log (texto ja limpo), inclusive nos .zip
      de meses compactados pelo organizador. Filtro de datas (De / Ate).
    - Mostra o log LIMPO: sem cores/codigos de controle, com backspaces aplicados e sem
      ---- More ---- / --More-- / ---(more)---, com as ocorrencias destacadas.
    - Abrir limpo (Bloco de Notas), Salvar limpo, Exportar limpos (todos da lista), Abrir pasta, Copiar.

    COMPARAR (diff)
    - Selecione 2 logs (Ctrl+clique) e clique em "Comparar", ou selecione 1 e clique em
      "Comparar com anterior" (pega o log anterior do mesmo equipamento na lista).
    - Escolha o mesmo comando nos dois logs (ex.: display current-configuration) ou o log inteiro.
      "dis cur" e "display current-configuration" sao reconhecidos como o mesmo comando.
    - Linhas removidas em vermelho, adicionadas em verde. Opcoes: ignorar numeros (contadores,
      uptime) e espacos, mostrar so as mudancas.

    Atalhos: Enter = pesquisar, F3 / Shift+F3 = proxima / anterior ocorrencia,
             duplo clique no resultado = abrir limpo.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -STA -File .\Pesquisar-Logs.ps1
#>
param([string[]]$Pastas)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

try {
    . (Join-Path $PSScriptRoot 'MobaLogBusca.ps1')
    if (-not $Pastas) { $Pastas = Get-MobaLogPastasPadrao }
} catch {
    [Windows.Forms.MessageBox]::Show("Erro ao carregar: $_", 'Pesquisar logs', 'OK', 'Error') | Out-Null
    return
}

# ------------------------------------------------------------------ tema escuro
function Cor([int]$R, [int]$G, [int]$B) { [Drawing.Color]::FromArgb($R, $G, $B) }
$Tema = @{
    Fundo     = Cor 24 24 27
    Painel    = Cor 32 32 36
    Campo     = Cor 42 42 48
    Borda     = Cor 70 70 80
    Texto     = Cor 232 232 236
    Apagado   = Cor 150 150 160
    Botao     = Cor 52 52 60
    BotaoHover = Cor 68 68 78
    Destaque  = Cor 0 120 212
    DestaqueHover = Cor 30 144 235
    Achado    = Cor 255 200 0
    Terminal  = Cor 18 18 20
}
$FonteBase = New-Object Drawing.Font('Segoe UI', 11)
$FonteTitulo = New-Object Drawing.Font('Segoe UI Semibold', 11)
$FonteMono = New-Object Drawing.Font('Consolas', 11.5)

function Pt([int]$X, [int]$Y) { New-Object Drawing.Point($X, $Y) }
function Margem([int]$E, [int]$C, [int]$D, [int]$B) { New-Object Windows.Forms.Padding($E, $C, $D, $B) }

function New-Rotulo([string]$Texto, [switch]$Apagado) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $Texto; $l.AutoSize = $true; $l.Margin = Margem 6 10 2 0
    $l.ForeColor = $(if ($Apagado) { $Tema.Apagado } else { $Tema.Texto })
    return $l
}

function New-Botao([string]$Texto, [int]$Largura = 120, [switch]$Principal) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $Texto; $b.Width = $Largura; $b.Height = 38; $b.Margin = Margem 4 3 4 3
    $b.FlatStyle = 'Flat'; $b.Cursor = [Windows.Forms.Cursors]::Hand
    $b.ForeColor = [Drawing.Color]::White
    $b.BackColor = $(if ($Principal) { $Tema.Destaque } else { $Tema.Botao })
    $b.FlatAppearance.BorderColor = $(if ($Principal) { $Tema.Destaque } else { $Tema.Borda })
    $b.FlatAppearance.MouseOverBackColor = $(if ($Principal) { $Tema.DestaqueHover } else { $Tema.BotaoHover })
    return $b
}

function New-Caixa([int]$Largura) {
    $t = New-Object Windows.Forms.TextBox
    $t.Width = $Largura; $t.Margin = Margem 4 6 4 3; $t.BorderStyle = 'FixedSingle'
    $t.BackColor = $Tema.Campo; $t.ForeColor = $Tema.Texto
    return $t
}

function New-Marcador([string]$Texto, [bool]$Marcado = $false) {
    $c = New-Object Windows.Forms.CheckBox
    $c.Text = $Texto; $c.AutoSize = $true; $c.Checked = $Marcado; $c.Margin = Margem 8 9 4 0
    $c.ForeColor = $Tema.Texto
    return $c
}

function New-Data {
    $d = New-Object Windows.Forms.DateTimePicker
    $d.Format = 'Short'; $d.Width = 140; $d.ShowCheckBox = $true; $d.Checked = $false; $d.Margin = Margem 4 6 4 3
    $d.CalendarMonthBackground = $Tema.Campo; $d.CalendarForeColor = $Tema.Texto
    return $d
}

function New-Linha {
    $f = New-Object Windows.Forms.FlowLayoutPanel
    $f.AutoSize = $true; $f.WrapContents = $false; $f.Dock = 'Fill'; $f.Margin = Margem 0 0 0 0
    return $f
}

function New-TextoTerminal {
    $r = New-Object Windows.Forms.RichTextBox
    $r.Dock = 'Fill'; $r.ReadOnly = $true; $r.WordWrap = $false; $r.DetectUrls = $false; $r.HideSelection = $false
    $r.Font = $FonteMono; $r.BackColor = $Tema.Terminal; $r.ForeColor = Cor 220 220 220; $r.BorderStyle = 'None'
    return $r
}

function New-Barra {
    $f = New-Object Windows.Forms.FlowLayoutPanel
    $f.Dock = 'Top'; $f.AutoSize = $true; $f.WrapContents = $true; $f.Padding = Margem 6 4 6 4
    $f.BackColor = $Tema.Painel
    return $f
}

function Set-Tema($Form) {
    $Form.BackColor = $Tema.Fundo; $Form.ForeColor = $Tema.Texto; $Form.Font = $FonteBase
    # barra de titulo escura no Windows 10/11
    try {
        if (-not ('MobaTools.Janela' -as [type])) {
            Add-Type -Namespace MobaTools -Name Janela -MemberDefinition '[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);'
        }
        $Form.Add_HandleCreated({ param($s, $e) $um = 1; [void][MobaTools.Janela]::DwmSetWindowAttribute($s.Handle, 20, [ref]$um, 4) })
    } catch { }
}

# ------------------------------------------------------------------ estado
$script:resultados = New-Object Collections.ArrayList
$script:parar = $false
$script:rx = $null
$script:textoAtual = ''
$script:ocorrencias = @()
$script:indiceOc = -1
$script:itemAtual = $null
$script:ordem = @{ Coluna = 0; Desc = $true }

# ------------------------------------------------------------------ janela principal
$form = New-Object Windows.Forms.Form
$form.Text = 'Pesquisar logs do MobaXterm'
$form.Size = New-Object Drawing.Size(1450, 920)
$form.MinimumSize = New-Object Drawing.Size(1000, 600)
$form.StartPosition = 'CenterScreen'; $form.KeyPreview = $true
Set-Tema $form
try { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon((Get-MobaConfig).MobaExe) } catch { }

$topo = New-Object Windows.Forms.TableLayoutPanel
$topo.Dock = 'Top'; $topo.AutoSize = $true; $topo.ColumnCount = 1; $topo.RowCount = 2
$topo.Padding = Margem 8 8 8 6; $topo.BackColor = $Tema.Painel

$l1 = New-Linha
$txtBusca = New-Caixa 360; $txtBusca.Font = New-Object Drawing.Font('Segoe UI', 12)
$chkRegex = New-Marcador 'Regex'
$chkNome = New-Marcador 'No nome' $true
$chkConteudo = New-Marcador 'No conteudo' $true
$dtDe = New-Data; $dtAte = New-Data
$btnBuscar = New-Botao 'Pesquisar' 130 -Principal
$btnParar = New-Botao 'Parar' 90; $btnParar.Enabled = $false
$l1.Controls.AddRange(@((New-Rotulo 'Procurar:'), $txtBusca, $chkRegex, $chkNome, $chkConteudo,
    (New-Rotulo 'De:'), $dtDe, (New-Rotulo 'Ate:'), $dtAte, $btnBuscar, $btnParar))

$l2 = New-Linha
$txtPastas = New-Caixa 760; $txtPastas.Text = ($Pastas -join '; ')
$btnPasta = New-Botao 'Escolher pasta...' 150
$lblStatus = New-Rotulo $(if ($Pastas) { 'Digite um hostname, IP ou texto e tecle Enter.' } else { 'Nenhuma pasta de logs encontrada: escolha uma.' }) -Apagado
$l2.Controls.AddRange(@((New-Rotulo 'Pastas:'), $txtPastas, $btnPasta, $lblStatus))

$topo.Controls.Add($l1, 0, 0); $topo.Controls.Add($l2, 0, 1)

$split = New-Object Windows.Forms.SplitContainer
$split.Dock = 'Fill'; $split.Orientation = 'Horizontal'; $split.BackColor = $Tema.Borda; $split.SplitterWidth = 5
$split.Panel1.BackColor = $Tema.Fundo; $split.Panel2.BackColor = $Tema.Fundo

$lista = New-Object Windows.Forms.ListView
$lista.Dock = 'Fill'; $lista.View = 'Details'; $lista.FullRowSelect = $true; $lista.HideSelection = $false
$lista.MultiSelect = $true; $lista.BorderStyle = 'None'; $lista.OwnerDraw = $true
$lista.BackColor = $Tema.Painel; $lista.ForeColor = $Tema.Texto
foreach ($col in @(@('Data', 105), @('Arquivo', 400), @('Host', 140), @('Ocorr.', 70), @('Primeira ocorrencia', 460), @('Local', 240))) {
    [void]$lista.Columns.Add($col[0], $col[1])
}
$pincelCabecalho = New-Object Drawing.SolidBrush($Tema.Campo)
$canetaBorda = New-Object Drawing.Pen($Tema.Borda)
$lista.Add_DrawColumnHeader({
    param($s, $e)
    $e.Graphics.FillRectangle($pincelCabecalho, $e.Bounds)
    $e.Graphics.DrawLine($canetaBorda, $e.Bounds.Right - 1, $e.Bounds.Top + 4, $e.Bounds.Right - 1, $e.Bounds.Bottom - 4)
    $r = New-Object Drawing.Rectangle(($e.Bounds.X + 8), $e.Bounds.Y, ($e.Bounds.Width - 10), $e.Bounds.Height)
    [Windows.Forms.TextRenderer]::DrawText($e.Graphics, $e.Header.Text, $FonteTitulo, $r, $Tema.Texto,
        [Windows.Forms.TextFormatFlags]'VerticalCenter, Left, EndEllipsis')
})
$lista.Add_DrawItem({ param($s, $e) $e.DrawDefault = $true })
$lista.Add_DrawSubItem({ param($s, $e) $e.DrawDefault = $true })
$split.Panel1.Controls.Add($lista)

$barra = New-Barra
$btnAnt = New-Botao '<  Anterior' 110
$btnProx = New-Botao 'Proxima  >' 110
$lblOc = New-Rotulo '' -Apagado; $lblOc.Margin = Margem 8 12 16 0
$btnComparar = New-Botao 'Comparar' 110 -Principal
$btnAnterior = New-Botao 'Comparar com anterior' 190
$btnAbrir = New-Botao 'Abrir limpo' 115
$btnSalvar = New-Botao 'Salvar limpo...' 135
$btnExportar = New-Botao 'Exportar limpos...' 155
$btnAbrirPasta = New-Botao 'Abrir pasta' 115
$btnCopiar = New-Botao 'Copiar tudo' 115
$barra.Controls.AddRange(@($btnAnt, $btnProx, $lblOc, $btnComparar, $btnAnterior, $btnAbrir, $btnSalvar, $btnExportar, $btnAbrirPasta, $btnCopiar))

$texto = New-TextoTerminal
$split.Panel2.Controls.Add($texto)
$split.Panel2.Controls.Add($barra)

$form.Controls.Add($split)
$form.Controls.Add($topo)
$form.AcceptButton = $btnBuscar

# ------------------------------------------------------------------ funcoes
function Show-Aviso([string]$Msg) { [Windows.Forms.MessageBox]::Show($Msg, 'Pesquisar logs') | Out-Null }

function Set-Ocupado([bool]$Ocupado) {
    $btnBuscar.Enabled = -not $Ocupado
    $btnParar.Enabled = $Ocupado
    $form.Cursor = $(if ($Ocupado) { [Windows.Forms.Cursors]::WaitCursor } else { [Windows.Forms.Cursors]::Default })
}

function Get-Local($r) {
    if ($r.Entrada) { return "zip: $([IO.Path]::GetFileName($r.Caminho))" }
    return Split-Path $r.Caminho -Parent
}

function Add-Resultado($r) {
    $li = New-Object Windows.Forms.ListViewItem($r.Data.ToString('dd/MM/yyyy'))
    [void]$li.SubItems.Add($r.Nome)
    [void]$li.SubItems.Add([string]$r.Host)
    [void]$li.SubItems.Add([string]$r.Ocorrencias)
    [void]$li.SubItems.Add($r.Trecho)
    [void]$li.SubItems.Add((Get-Local $r))
    $li.Tag = $r
    [void]$lista.Items.Add($li)
}

function Show-Lista {
    $props = 'Data', 'Nome', 'Host', 'Ocorrencias', 'Trecho', 'Caminho'
    $ordenados = $script:resultados | Sort-Object -Property $props[$script:ordem.Coluna] -Descending:$script:ordem.Desc
    $lista.BeginUpdate(); $lista.Items.Clear()
    foreach ($r in $ordenados) { Add-Resultado $r }
    $lista.EndUpdate()
}

function Start-Pesquisa {
    $busca = $txtBusca.Text.Trim()
    if (-not $busca) { $txtBusca.Focus(); return }
    if (-not $chkNome.Checked -and -not $chkConteudo.Checked) { $chkConteudo.Checked = $true }
    try { $script:rx = New-MobaLogRegex -Texto $busca -Regex:$chkRegex.Checked }
    catch { Show-Aviso "Regex invalida: $($_.Exception.InnerException.Message)"; return }

    $pastas = @($txtPastas.Text -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $script:resultados.Clear(); $lista.Items.Clear(); $texto.Clear(); $lblOc.Text = ''
    $script:itemAtual = $null; $script:parar = $false
    Set-Ocupado $true
    $relogio = [Diagnostics.Stopwatch]::StartNew()
    try {
        $lblStatus.Text = 'Listando arquivos...'; [Windows.Forms.Application]::DoEvents()
        $itens = @(Get-MobaLogArquivos -Pastas $pastas)
        if ($dtDe.Checked) { $itens = @($itens | Where-Object { $_.Data.Date -ge $dtDe.Value.Date }) }
        if ($dtAte.Checked) { $itens = @($itens | Where-Object { $_.Data.Date -le $dtAte.Value.Date }) }
        $itens = @($itens | Sort-Object Data -Descending)
        $n = 0
        foreach ($it in $itens) {
            $n++
            if ($n % 3 -eq 0) { $lblStatus.Text = "Procurando... $n de $($itens.Count)"; [Windows.Forms.Application]::DoEvents() }
            if ($script:parar) { break }
            try { $achou = Find-MobaLogTexto -Item $it -Rx $script:rx -NoNome:$chkNome.Checked -NoConteudo:$chkConteudo.Checked }
            catch { continue }
            if ($achou) {
                $r = [pscustomobject]@{ Data = $it.Data; Nome = $it.Nome; Host = $it.Host; Ocorrencias = $achou.Ocorrencias
                    Trecho = $achou.Trecho; Caminho = $it.Caminho; Entrada = $it.Entrada; Tamanho = $it.Tamanho }
                [void]$script:resultados.Add($r)
                Add-Resultado $r
            }
        }
        $fim = if ($script:parar) { ' (interrompido)' } else { '' }
        $lblStatus.Text = '{0} log(s) com "{1}" em {2} arquivo(s) - {3:N1} s{4}' -f $script:resultados.Count, $busca, $itens.Count, $relogio.Elapsed.TotalSeconds, $fim
    } catch {
        $lblStatus.Text = "Erro: $_"
    } finally { Set-Ocupado $false }
}

function Show-Log($r) {
    $script:itemAtual = $r
    try { $script:textoAtual = Read-MobaLog $r } catch { $texto.Text = "Nao foi possivel ler: $_"; return }
    $texto.Text = $script:textoAtual            # o RichTextBox troca \r\n por \n: indices sao do $texto.Text
    $script:ocorrencias = @()
    $script:indiceOc = -1
    if ($script:rx) {
        $script:ocorrencias = @($script:rx.Matches($texto.Text))
        foreach ($m in ($script:ocorrencias | Select-Object -First 500)) {
            $texto.Select($m.Index, $m.Length)
            $texto.SelectionBackColor = $Tema.Achado
            $texto.SelectionColor = [Drawing.Color]::Black
        }
    }
    if ($script:ocorrencias.Count) { Move-Ocorrencia 1 } else { $texto.Select(0, 0); $lblOc.Text = '(achado pelo nome do arquivo)' }
}

function Move-Ocorrencia([int]$Passo) {
    $total = $script:ocorrencias.Count
    if (-not $total) { return }
    $script:indiceOc = ($script:indiceOc + $Passo + $total) % $total
    $m = $script:ocorrencias[$script:indiceOc]
    $texto.Select($m.Index, $m.Length)
    $texto.ScrollToCaret()
    $linha = $texto.GetLineFromCharIndex($m.Index) + 1
    $extra = if ($total -gt 500) { ' (destaque nas 500 primeiras)' } else { '' }
    $lblOc.Text = "Ocorrencia $($script:indiceOc + 1) de $total - linha $linha$extra"
}

function Get-NomeLimpo($r) { [IO.Path]::GetFileNameWithoutExtension($r.Nome) + '.limpo.txt' }

function Save-Texto([string]$Destino, [string]$Conteudo) {
    [IO.File]::WriteAllText($Destino, $Conteudo, (New-Object Text.UTF8Encoding($true)))
}

function Open-NoBloco([string]$Nome, [string]$Conteudo) {
    $pasta = Join-Path $env:TEMP 'MobaLogs'
    New-Item -ItemType Directory -Path $pasta -Force | Out-Null
    $arq = Join-Path $pasta $Nome
    Save-Texto $arq $Conteudo
    Start-Process notepad.exe -ArgumentList ('"{0}"' -f $arq)
}

function Export-Limpos {
    if (-not $script:resultados.Count) { Show-Aviso 'Pesquise primeiro: sao exportados os logs da lista.'; return }
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Pasta para salvar os logs limpos (uma subpasta por equipamento)'
    if ($dlg.ShowDialog() -ne 'OK') { return }
    Set-Ocupado $true
    $n = 0
    try {
        foreach ($r in $script:resultados) {
            $n++; $lblStatus.Text = "Exportando $n de $($script:resultados.Count)..."; [Windows.Forms.Application]::DoEvents()
            $equip = (Get-MobaLogChaveEquipamento $r) -replace '[\\/:*?"<>|]', '_'
            if (-not $equip) { $equip = 'sem-nome' }
            $pasta = Join-Path $dlg.SelectedPath $equip
            New-Item -ItemType Directory -Path $pasta -Force | Out-Null
            Save-Texto (Join-Path $pasta ('{0:yyyy-MM-dd}_{1}' -f $r.Data, (Get-NomeLimpo $r))) (Read-MobaLog $r)
        }
        $lblStatus.Text = "$n log(s) limpos exportados para $($dlg.SelectedPath)"
        Start-Process explorer.exe -ArgumentList ('"{0}"' -f $dlg.SelectedPath)
    } catch { $lblStatus.Text = "Erro ao exportar: $_" } finally { Set-Ocupado $false }
}

function Find-LogAnterior($r) {
    $chave = Get-MobaLogChaveEquipamento $r
    return $script:resultados |
        Where-Object { $_ -ne $r -and (Get-MobaLogChaveEquipamento $_) -eq $chave -and
            ($_.Data -lt $r.Data -or ($_.Data -eq $r.Data -and $_.Nome -lt $r.Nome)) } |
        Sort-Object Data, Nome | Select-Object -Last 1
}

# ------------------------------------------------------------------ janela de comparacao
# Estado da janela de comparacao aberta (ela e modal: uma por vez)
$script:cmp = $null

function New-Combo {
    $c = New-Object Windows.Forms.ComboBox
    $c.DropDownStyle = 'DropDownList'; $c.Width = 560; $c.Margin = Margem 4 5 4 3
    $c.BackColor = $Tema.Campo; $c.ForeColor = $Tema.Texto; $c.FlatStyle = 'Flat'; $c.MaxDropDownItems = 25
    return $c
}

function Invoke-Comparar {
    $c = $script:cmp
    $ta = if ($c.CmbA.SelectedItem -is [MobaBloco]) { $c.CmbA.SelectedItem.Texto } else { $c.TextoA }
    $tb = if ($c.CmbB.SelectedItem -is [MobaBloco]) { $c.CmbB.SelectedItem.Texto } else { $c.TextoB }
    $c.Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
    try {
        $r = Compare-MobaLog $ta $tb -IgnorarNumeros:$c.ChkNum.Checked -IgnorarEspacos:$c.ChkEsp.Checked
        $vis = [MobaDiff]::Visiveis($r.Linhas, $(if ($c.ChkSo.Checked) { 3 } else { -1 }))
        if ($r.Adicionadas + $r.Removidas -eq 0) {
            $c.Saida.Text = "`r`n   Nenhuma diferenca.`r`n"
            $c.Resultado.Text = 'Iguais'
        } else {
            $c.Saida.Rtf = [MobaDiff]::ParaRtf($vis)
            $c.Resultado.Text = "+$($r.Adicionadas) adicionada(s)    -$($r.Removidas) removida(s)"
        }
        $cab = "A: {0:dd/MM/yyyy} {1} [{2}]`r`nB: {3:dd/MM/yyyy} {4} [{5}]`r`n+{6} / -{7}`r`n`r`n" -f `
            $c.A.Data, $c.A.Nome, $c.CmbA.Text, $c.B.Data, $c.B.Nome, $c.CmbB.Text, $r.Adicionadas, $r.Removidas
        $c.Texto = $cab + [MobaDiff]::ParaTexto($vis)
    } catch {
        $c.Saida.Text = "Erro: $($_.Exception.Message)"
        $c.Resultado.Text = ''
    } finally { $c.Form.Cursor = [Windows.Forms.Cursors]::Default }
}

function Select-MesmoComandoEmB {
    # escolher um comando em A seleciona o mesmo comando em B (ultima ocorrencia)
    $c = $script:cmp
    if ($c.CmbA.SelectedItem -is [MobaBloco]) {
        $chave = $c.CmbA.SelectedItem.Chave
        for ($i = $c.CmbB.Items.Count - 1; $i -ge 1; $i--) {
            if ($c.CmbB.Items[$i].Chave -eq $chave) { $c.CmbB.SelectedIndex = $i; return }
        }
    } else { $c.CmbB.SelectedIndex = 0 }
}

function Get-NomeDiff { 'diff_{0:yyyy-MM-dd}_x_{1:yyyy-MM-dd}.txt' -f $script:cmp.A.Data, $script:cmp.B.Data }

function Show-Comparacao($A, $B) {
    # A = mais antigo, B = mais novo
    if ($A.Data -gt $B.Data -or ($A.Data -eq $B.Data -and $A.Nome -gt $B.Nome)) { $t = $A; $A = $B; $B = $t }
    try { $textoA = Read-MobaLog $A; $textoB = Read-MobaLog $B } catch { Show-Aviso "Nao foi possivel ler: $_"; return }
    $blocosA = Get-MobaLogBlocos $textoA
    $blocosB = Get-MobaLogBlocos $textoB

    $f = New-Object Windows.Forms.Form
    $f.Text = "Comparar:  $($A.Nome)   x   $($B.Nome)"
    $f.Size = New-Object Drawing.Size(1400, 900); $f.StartPosition = 'CenterParent'
    Set-Tema $f

    $cab = New-Object Windows.Forms.TableLayoutPanel
    $cab.Dock = 'Top'; $cab.AutoSize = $true; $cab.ColumnCount = 1; $cab.RowCount = 3
    $cab.Padding = Margem 8 8 8 6; $cab.BackColor = $Tema.Painel

    $cmbA = New-Combo; $cmbB = New-Combo
    [void]$cmbA.Items.Add('(log inteiro)'); foreach ($x in $blocosA) { [void]$cmbA.Items.Add($x) }
    [void]$cmbB.Items.Add('(log inteiro)'); foreach ($x in $blocosB) { [void]$cmbB.Items.Add($x) }

    $la = New-Linha
    $rotA = New-Rotulo ('A  (antes)   {0:dd/MM/yyyy}' -f $A.Data); $rotA.ForeColor = Cor 255 120 120; $rotA.Width = 210; $rotA.AutoSize = $false
    $la.Controls.AddRange(@($rotA, $cmbA, (New-Rotulo $A.Nome -Apagado)))
    $lb = New-Linha
    $rotB = New-Rotulo ('B  (depois)  {0:dd/MM/yyyy}' -f $B.Data); $rotB.ForeColor = Cor 120 230 120; $rotB.Width = 210; $rotB.AutoSize = $false
    $lb.Controls.AddRange(@($rotB, $cmbB, (New-Rotulo $B.Nome -Apagado)))

    $lo = New-Linha
    $chkNum = New-Marcador 'Ignorar numeros (contadores, uptime)'
    $chkEsp = New-Marcador 'Ignorar espacos'
    $chkSo = New-Marcador 'So as mudancas' $true
    $btnCmp = New-Botao 'Comparar' 120 -Principal
    $btnSalvarDiff = New-Botao 'Salvar diff...' 130
    $btnBlocoDiff = New-Botao 'Abrir no Bloco de Notas' 210
    $lblRes = New-Rotulo '' ; $lblRes.Font = $FonteTitulo
    $lo.Controls.AddRange(@($chkNum, $chkEsp, $chkSo, $btnCmp, $btnSalvarDiff, $btnBlocoDiff, $lblRes))

    $cab.Controls.Add($la, 0, 0); $cab.Controls.Add($lb, 0, 1); $cab.Controls.Add($lo, 0, 2)
    $saida = New-TextoTerminal
    $f.Controls.Add($saida)
    $f.Controls.Add($cab)

    $script:cmp = @{ A = $A; B = $B; TextoA = $textoA; TextoB = $textoB; CmbA = $cmbA; CmbB = $cmbB
        ChkNum = $chkNum; ChkEsp = $chkEsp; ChkSo = $chkSo; Saida = $saida; Resultado = $lblRes; Form = $f; Texto = '' }

    $cmbA.Add_SelectedIndexChanged({ Select-MesmoComandoEmB })

    # padrao: a config se existir nos dois; senao o ultimo comando em comum; senao o log inteiro
    $chavesB = @($blocosB | ForEach-Object { $_.Chave })
    $comuns = @($blocosA | Where-Object { $chavesB -contains $_.Chave })
    $preferido = $comuns | Where-Object { $_.Chave -match 'current-configuration|running-config|configuration' } | Select-Object -Last 1
    if (-not $preferido) { $preferido = $comuns | Select-Object -Last 1 }
    $cmbA.SelectedIndex = $(if ($preferido) { $cmbA.Items.IndexOf($preferido) } else { 0 })
    if ($cmbB.SelectedIndex -lt 0) { $cmbB.SelectedIndex = 0 }

    $btnCmp.Add_Click({ Invoke-Comparar })
    $chkNum.Add_CheckedChanged({ Invoke-Comparar })
    $chkEsp.Add_CheckedChanged({ Invoke-Comparar })
    $chkSo.Add_CheckedChanged({ Invoke-Comparar })
    $btnSalvarDiff.Add_Click({
        $dlg = New-Object Windows.Forms.SaveFileDialog
        $dlg.FileName = Get-NomeDiff
        $dlg.Filter = 'Texto (*.txt)|*.txt|Todos (*.*)|*.*'
        if ($dlg.ShowDialog() -eq 'OK') { Save-Texto $dlg.FileName $script:cmp.Texto }
    })
    $btnBlocoDiff.Add_Click({ Open-NoBloco (Get-NomeDiff) $script:cmp.Texto })
    $f.Add_Shown({ Invoke-Comparar })
    [void]$f.ShowDialog($form)
    $f.Dispose()
    $script:cmp = $null
}

# ------------------------------------------------------------------ eventos
$btnBuscar.Add_Click({ Start-Pesquisa })
$btnParar.Add_Click({ $script:parar = $true })
$btnPasta.Add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Pasta com os logs do MobaXterm'
    if ($dlg.ShowDialog() -eq 'OK') { $txtPastas.Text = $dlg.SelectedPath; $lblStatus.Text = 'Pasta escolhida. Tecle Enter para pesquisar.' }
})
$lista.Add_SelectedIndexChanged({
    $n = $lista.SelectedItems.Count
    if ($n -eq 1) { Show-Log $lista.SelectedItems[0].Tag }
    elseif ($n -eq 2) { $lblOc.Text = '2 logs selecionados: clique em Comparar' }
})
$lista.Add_DoubleClick({ $btnAbrir.PerformClick() })
$lista.Add_ColumnClick({
    param($s, $e)
    if ($script:ordem.Coluna -eq $e.Column) { $script:ordem.Desc = -not $script:ordem.Desc }
    else { $script:ordem.Coluna = $e.Column; $script:ordem.Desc = ($e.Column -in 0, 3) }
    Show-Lista
})
$btnProx.Add_Click({ Move-Ocorrencia 1 })
$btnAnt.Add_Click({ Move-Ocorrencia -1 })
$btnComparar.Add_Click({
    if ($lista.SelectedItems.Count -ne 2) { Show-Aviso 'Selecione 2 logs na lista (Ctrl+clique) para comparar, ou use "Comparar com anterior".'; return }
    Show-Comparacao $lista.SelectedItems[0].Tag $lista.SelectedItems[1].Tag
})
$btnAnterior.Add_Click({
    if (-not $script:itemAtual) { Show-Aviso 'Selecione um log na lista.'; return }
    $ant = Find-LogAnterior $script:itemAtual
    if (-not $ant) { Show-Aviso "Nao ha log anterior desse equipamento na lista.`nPesquise pelo hostname ou IP para listar todos os logs dele."; return }
    Show-Comparacao $ant $script:itemAtual
})
$btnAbrir.Add_Click({ if ($script:itemAtual) { Open-NoBloco (Get-NomeLimpo $script:itemAtual) $script:textoAtual } })
$btnSalvar.Add_Click({
    if (-not $script:itemAtual) { return }
    $dlg = New-Object Windows.Forms.SaveFileDialog
    $dlg.FileName = Get-NomeLimpo $script:itemAtual
    $dlg.Filter = 'Texto (*.txt)|*.txt|Todos (*.*)|*.*'
    if ($dlg.ShowDialog() -eq 'OK') { Save-Texto $dlg.FileName $script:textoAtual; $lblStatus.Text = "Salvo: $($dlg.FileName)" }
})
$btnExportar.Add_Click({ Export-Limpos })
$btnAbrirPasta.Add_Click({
    if (-not $script:itemAtual) { return }
    Start-Process explorer.exe -ArgumentList ('/select,"{0}"' -f $script:itemAtual.Caminho)
})
$btnCopiar.Add_Click({ if ($script:textoAtual) { [Windows.Forms.Clipboard]::SetText($script:textoAtual); $lblStatus.Text = 'Log limpo copiado.' } })
$form.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq 'F3') { Move-Ocorrencia $(if ($e.Shift) { -1 } else { 1 }); $e.Handled = $true }
})
$form.Add_Shown({ $split.SplitterDistance = 300; $txtBusca.Focus() })

[void]$form.ShowDialog()
$form.Dispose()
