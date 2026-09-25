<#
.SYNOPSIS
    Janela para pesquisar nos logs do MobaXterm (hostname, IP, comando, qualquer texto).

.DESCRIPTION
    - Procura no NOME do arquivo e/ou DENTRO do log (texto ja limpo), inclusive nos .zip
      de meses compactados pelo organizador.
    - Filtro de datas (De / Ate). A data vem das pastas Ano\Mes\Dia, do nome do log ou
      da data do arquivo.
    - Mostra o log LIMPO: sem cores/codigos de controle, com backspaces aplicados e sem
      ---- More ---- / --More-- / ---(more)---, com as ocorrencias destacadas.
    - Abrir limpo (Bloco de Notas), Salvar limpo, Abrir pasta, Copiar.
    Atalhos: Enter = pesquisar, F3 / Shift+F3 = proxima / anterior ocorrencia,
             duplo clique no resultado = abrir limpo.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -STA -File .\Pesquisar-Logs.ps1
.EXAMPLE
    .\Pesquisar-Logs.ps1 -Pastas 'D:\Logs\Moba', '\\servidor\logs'
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

$script:resultados = New-Object Collections.ArrayList
$script:parar = $false
$script:rx = $null
$script:textoAtual = ''
$script:ocorrencias = @()
$script:indiceOc = -1
$script:itemAtual = $null
$script:ordem = @{ Coluna = 0; Desc = $true }

function Pt([int]$X, [int]$Y) { New-Object Drawing.Point($X, $Y) }

function New-Controle([string]$Tipo, [hashtable]$Props) {
    $c = New-Object "Windows.Forms.$Tipo"
    foreach ($k in $Props.Keys) { $c.$k = $Props[$k] }
    return $c
}

# ------------------------------------------------------------------ janela
$form = New-Controle Form @{ Text = 'Pesquisar logs do MobaXterm'; Size = New-Object Drawing.Size(1250, 820)
    StartPosition = 'CenterScreen'; KeyPreview = $true; Font = New-Object Drawing.Font('Segoe UI', 9) }
try { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon((Get-MobaConfig).MobaExe) } catch { }

$topo = New-Controle Panel @{ Dock = 'Top'; Height = 76 }
$lblBusca = New-Controle Label @{ Text = 'Procurar:'; Location = (Pt 10 14); AutoSize = $true }
$txtBusca = New-Controle TextBox @{ Location = (Pt 75 10); Width = 330 }
$chkRegex = New-Controle CheckBox @{ Text = 'Regex'; Location = (Pt 415 11); AutoSize = $true }
$chkNome = New-Controle CheckBox @{ Text = 'No nome'; Location = (Pt 480 11); AutoSize = $true; Checked = $true }
$chkConteudo = New-Controle CheckBox @{ Text = 'No conteudo'; Location = (Pt 560 11); AutoSize = $true; Checked = $true }
$lblDe = New-Controle Label @{ Text = 'De:'; Location = (Pt 665 14); AutoSize = $true }
$dtDe = New-Controle DateTimePicker @{ Location = (Pt 690 10); Width = 125; Format = 'Short'; ShowCheckBox = $true; Checked = $false }
$lblAte = New-Controle Label @{ Text = 'Ate:'; Location = (Pt 822 14); AutoSize = $true }
$dtAte = New-Controle DateTimePicker @{ Location = (Pt 850 10); Width = 125; Format = 'Short'; ShowCheckBox = $true; Checked = $false }
$btnBuscar = New-Controle Button @{ Text = 'Pesquisar'; Location = (Pt 985 8); Width = 100; Height = 27 }
$btnParar = New-Controle Button @{ Text = 'Parar'; Location = (Pt 1090 8); Width = 70; Height = 27; Enabled = $false }
$lblPastas = New-Controle Label @{ Text = 'Pastas:'; Location = (Pt 10 48); AutoSize = $true }
$txtPastas = New-Controle TextBox @{ Location = (Pt 75 44); Width = 700; Text = ($Pastas -join '; ') }
$btnPasta = New-Controle Button @{ Text = 'Escolher pasta...'; Location = (Pt 780 42); Width = 115; Height = 27 }
$lblStatus = New-Controle Label @{ Location = (Pt 905 48); AutoSize = $true; ForeColor = [Drawing.Color]::DimGray
    Text = $(if ($Pastas) { 'Digite um hostname, IP ou texto e tecle Enter.' } else { 'Nenhuma pasta de logs encontrada: escolha uma.' }) }
$txtBusca.Anchor = 'Top, Left'
$topo.Controls.AddRange(@($lblBusca, $txtBusca, $chkRegex, $chkNome, $chkConteudo, $lblDe, $dtDe, $lblAte, $dtAte,
    $btnBuscar, $btnParar, $lblPastas, $txtPastas, $btnPasta, $lblStatus))

$split = New-Controle SplitContainer @{ Dock = 'Fill'; Orientation = 'Horizontal' }

$lista = New-Controle ListView @{ Dock = 'Fill'; View = 'Details'; FullRowSelect = $true; GridLines = $true
    HideSelection = $false; MultiSelect = $false }
foreach ($col in @(@('Data', 85), @('Arquivo', 360), @('Host', 115), @('Ocorr.', 55), @('Primeira ocorrencia', 420), @('Local', 230))) {
    [void]$lista.Columns.Add($col[0], $col[1])
}
$split.Panel1.Controls.Add($lista)

$barra = New-Controle FlowLayoutPanel @{ Dock = 'Top'; Height = 34; Padding = New-Object Windows.Forms.Padding(4) }
$btnAnt = New-Controle Button @{ Text = '< Anterior'; Width = 85 }
$btnProx = New-Controle Button @{ Text = 'Proxima >'; Width = 85 }
$lblOc = New-Controle Label @{ AutoSize = $true; Padding = New-Object Windows.Forms.Padding(4, 6, 12, 0) }
$btnAbrir = New-Controle Button @{ Text = 'Abrir limpo'; Width = 95 }
$btnSalvar = New-Controle Button @{ Text = 'Salvar limpo...'; Width = 105 }
$btnAbrirPasta = New-Controle Button @{ Text = 'Abrir pasta'; Width = 90 }
$btnCopiar = New-Controle Button @{ Text = 'Copiar tudo'; Width = 90 }
$barra.Controls.AddRange(@($btnAnt, $btnProx, $lblOc, $btnAbrir, $btnSalvar, $btnAbrirPasta, $btnCopiar))

$texto = New-Controle RichTextBox @{ Dock = 'Fill'; ReadOnly = $true; WordWrap = $false; DetectUrls = $false
    HideSelection = $false; Font = New-Object Drawing.Font('Consolas', 10)
    BackColor = [Drawing.Color]::FromArgb(30, 30, 30); ForeColor = [Drawing.Color]::FromArgb(220, 220, 220) }
$split.Panel2.Controls.Add($texto)
$split.Panel2.Controls.Add($barra)

$form.Controls.Add($split)
$form.Controls.Add($topo)
$form.AcceptButton = $btnBuscar

# ------------------------------------------------------------------ funcoes
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
    catch { [Windows.Forms.MessageBox]::Show("Regex invalida: $($_.Exception.InnerException.Message)", 'Pesquisar logs') | Out-Null; return }

    $pastas = @($txtPastas.Text -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $script:resultados.Clear(); $lista.Items.Clear(); $texto.Clear(); $lblOc.Text = ''
    $script:parar = $false
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
        $destaque = [Drawing.Color]::FromArgb(255, 200, 0)
        foreach ($m in ($script:ocorrencias | Select-Object -First 500)) {
            $texto.Select($m.Index, $m.Length)
            $texto.SelectionBackColor = $destaque
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

function Get-NomeLimpo {
    return [IO.Path]::GetFileNameWithoutExtension($script:itemAtual.Nome) + '.limpo.txt'
}

function Save-Limpo([string]$Destino) {
    [IO.File]::WriteAllText($Destino, $script:textoAtual, (New-Object Text.UTF8Encoding($true)))
}

# ------------------------------------------------------------------ eventos
$btnBuscar.Add_Click({ Start-Pesquisa })
$btnParar.Add_Click({ $script:parar = $true })
$btnPasta.Add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Pasta com os logs do MobaXterm'
    if ($dlg.ShowDialog() -eq 'OK') { $txtPastas.Text = $dlg.SelectedPath; $lblStatus.Text = 'Pasta escolhida. Tecle Enter para pesquisar.' }
})
$lista.Add_SelectedIndexChanged({ if ($lista.SelectedItems.Count -eq 1) { Show-Log $lista.SelectedItems[0].Tag } })
$lista.Add_DoubleClick({ $btnAbrir.PerformClick() })
$lista.Add_ColumnClick({
    param($s, $e)
    if ($script:ordem.Coluna -eq $e.Column) { $script:ordem.Desc = -not $script:ordem.Desc }
    else { $script:ordem.Coluna = $e.Column; $script:ordem.Desc = ($e.Column -in 0, 3) }
    Show-Lista
})
$btnProx.Add_Click({ Move-Ocorrencia 1 })
$btnAnt.Add_Click({ Move-Ocorrencia -1 })
$btnAbrir.Add_Click({
    if (-not $script:itemAtual) { return }
    $pasta = Join-Path $env:TEMP 'MobaLogs'
    New-Item -ItemType Directory -Path $pasta -Force | Out-Null
    $arq = Join-Path $pasta (Get-NomeLimpo)
    Save-Limpo $arq
    Start-Process notepad.exe -ArgumentList ('"{0}"' -f $arq)
})
$btnSalvar.Add_Click({
    if (-not $script:itemAtual) { return }
    $dlg = New-Object Windows.Forms.SaveFileDialog
    $dlg.FileName = Get-NomeLimpo
    $dlg.Filter = 'Texto (*.txt)|*.txt|Todos (*.*)|*.*'
    if ($dlg.ShowDialog() -eq 'OK') { Save-Limpo $dlg.FileName; $lblStatus.Text = "Salvo: $($dlg.FileName)" }
})
$btnAbrirPasta.Add_Click({
    if (-not $script:itemAtual) { return }
    Start-Process explorer.exe -ArgumentList ('/select,"{0}"' -f $script:itemAtual.Caminho)
})
$btnCopiar.Add_Click({ if ($script:textoAtual) { [Windows.Forms.Clipboard]::SetText($script:textoAtual); $lblStatus.Text = 'Log limpo copiado.' } })
$form.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq 'F3') { Move-Ocorrencia $(if ($e.Shift) { -1 } else { 1 }); $e.Handled = $true }
})
$form.Add_Shown({ $split.SplitterDistance = 260; $txtBusca.Focus() })

[void]$form.ShowDialog()
$form.Dispose()
