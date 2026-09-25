# Busca e limpeza de logs do MobaXterm. Usado pelo Pesquisar-Logs.ps1. Nao execute direto.
#
# A limpeza reconstrui o texto como ele apareceu na tela: aplica \r, backspace e os
# comandos de cursor/apagar do terminal (ESC[nD, ESC[K...), remove cores e codigos de
# controle e tira os restos de paginacao (---- More ----, --More--, ---(more)---).

. (Join-Path $PSScriptRoot 'MobaTools.Common.ps1')

if (-not ('MobaLogLimpo' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

public static class MobaLogLimpo
{
    // UTF-8 se for valido; senao Latin-1 (logs de equipamentos antigos)
    public static string Decodificar(byte[] b)
    {
        int ini = (b.Length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) ? 3 : 0;
        try { return new UTF8Encoding(false, true).GetString(b, ini, b.Length - ini); }
        catch (DecoderFallbackException) { return Encoding.GetEncoding(28591).GetString(b); }
    }

    public static string Limpar(string t)
    {
        StringBuilder saida = new StringBuilder(t.Length);
        List<char> linha = new List<char>(256);
        int col = 0, i = 0, n = t.Length;
        while (i < n)
        {
            char c = t[i];
            if (c == '\n') { Fechar(saida, linha); col = 0; i++; continue; }
            if (c == '\r') { if (i + 1 < n && t[i + 1] == '\n') { i++; continue; } col = 0; i++; continue; }
            if (c == '\b') { if (col > 0) col--; i++; continue; }
            if (c == '\x1b') { i = Escape(t, i, linha, ref col); continue; }
            if (c == '\t') { Escrever(linha, ref col, c); i++; continue; }
            if (c < ' ' || c == '\x7f' || (c >= '\x80' && c <= '\x9f')) { i++; continue; }
            Escrever(linha, ref col, c); i++;
        }
        if (linha.Count > 0) Fechar(saida, linha);

        string r = saida.ToString();
        // restos de paginacao que o terminal nao apagou
        r = Regex.Replace(r, @"^[ \t]*(-{2,4} ?More ?-{2,4}|--More--|---\(more( \d+%)?\)---)[ \t]*\r?\n",
                          "", RegexOptions.Multiline | RegexOptions.IgnoreCase);
        r = Regex.Replace(r, @"[ \t]*(-{2,4} ?More ?-{2,4}|--More--|---\(more( \d+%)?\)---)[ \t]*",
                          "", RegexOptions.IgnoreCase);
        // no maximo 2 linhas vazias seguidas
        r = Regex.Replace(r, @"(\r\n[ \t]*){3,}\r\n", "\r\n\r\n\r\n");
        return r;
    }

    static void Escrever(List<char> linha, ref int col, char c)
    {
        if (col < linha.Count) linha[col] = c;
        else { while (linha.Count < col) linha.Add(' '); linha.Add(c); }
        col++;
    }

    static void Fechar(StringBuilder saida, List<char> linha)
    {
        int fim = linha.Count;
        while (fim > 0 && (linha[fim - 1] == ' ' || linha[fim - 1] == '\t')) fim--;
        for (int k = 0; k < fim; k++) saida.Append(linha[k]);
        saida.Append("\r\n");
        linha.Clear();
    }

    static int Escape(string t, int i, List<char> linha, ref int col)
    {
        int n = t.Length;
        if (i + 1 >= n) return n;
        char k = t[i + 1];
        if (k == '[')
        {
            int j = i + 2;
            while (j < n && (t[j] < '@' || t[j] > '~')) j++;
            if (j >= n) return n;
            string p = t.Substring(i + 2, j - i - 2).TrimStart('?');
            int a = 0;
            string[] partes = p.Split(';');
            if (partes.Length > 0) int.TryParse(partes[0], out a);
            int q = a > 0 ? a : 1;
            switch (t[j])
            {
                case 'D': col = Math.Max(0, col - q); break;                  // cursor para tras
                case 'C': col += q; break;                                    // cursor para frente
                case 'G': col = Math.Max(0, q - 1); break;                    // coluna absoluta
                case 'K':                                                     // apagar na linha
                    if (a == 0) { if (col < linha.Count) linha.RemoveRange(col, linha.Count - col); }
                    else if (a == 1) { for (int x = 0; x < Math.Min(col + 1, linha.Count); x++) linha[x] = ' '; }
                    else linha.Clear();
                    break;
                case 'P': if (col < linha.Count) linha.RemoveRange(col, Math.Min(q, linha.Count - col)); break;
                case 'X': for (int x = col; x < Math.Min(col + q, linha.Count); x++) linha[x] = ' '; break;
                case '@': if (col < linha.Count) linha.InsertRange(col, new string(' ', q)); break;
                default: break;                                               // cores (m) e o resto: ignora
            }
            return j + 1;
        }
        if (k == ']')                                                         // OSC: titulo da janela etc.
        {
            int j = i + 2;
            while (j < n && t[j] != '\x07' && !(t[j] == '\x1b' && j + 1 < n && t[j + 1] == '\\')) j++;
            return j >= n ? n : (t[j] == '\x07' ? j + 1 : j + 2);
        }
        if (k == '(' || k == ')' || k == '*' || k == '+') return Math.Min(n, i + 3);
        return i + 2;
    }
}
'@
}

function Get-MobaLogPastasPadrao {
    # Pasta de logs do Moba + pasta de destino do organizador (sem repetir)
    $cfg = Get-MobaConfig
    $pastas = @()
    try { $pastas += Get-MobaPastaLogs $cfg } catch { }
    if ($cfg.PastaLogs) { $pastas += $cfg.PastaLogs }
    if ($cfg.PastaDestino) { $pastas += $cfg.PastaDestino }
    return @($pastas | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique)
}

function Get-MobaLogArquivos {
    # Lista os logs (.log/.txt), inclusive dentro dos .zip de meses compactados.
    # Cada item: Data, Nome, Host, Caminho, Entrada (nome dentro do zip ou $null), Tamanho
    param([string[]]$Pastas, [string[]]$Extensoes = @('.log', '.txt'))
    try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop } catch { }
    foreach ($pasta in $Pastas) {
        if (-not (Test-Path -LiteralPath $pasta)) { continue }
        foreach ($f in Get-ChildItem -LiteralPath $pasta -Recurse -File -ErrorAction SilentlyContinue) {
            $ext = $f.Extension.ToLower()
            if ($Extensoes -contains $ext -and $f.Name -ne '_organizador.log') {
                [pscustomobject]@{
                    Data = Get-DataDoLog -Nome $f.BaseName -Caminho $f.FullName -DataArquivo $f.LastWriteTime
                    Nome = $f.Name; Host = Get-MobaLogHost $f.BaseName
                    Caminho = $f.FullName; Entrada = $null; Tamanho = $f.Length
                }
            } elseif ($ext -eq '.zip') {
                try {
                    $zip = [IO.Compression.ZipFile]::OpenRead($f.FullName)
                    try {
                        $base = $f.FullName.Substring(0, $f.FullName.Length - 4)    # ...\2026\03-Marco
                        foreach ($e in $zip.Entries) {
                            if ($Extensoes -notcontains [IO.Path]::GetExtension($e.Name).ToLower()) { continue }
                            $nomeBase = [IO.Path]::GetFileNameWithoutExtension($e.Name)
                            [pscustomobject]@{
                                Data = Get-DataDoLog -Nome $nomeBase -Caminho ($base + '\' + ($e.FullName -replace '/', '\')) -DataArquivo $e.LastWriteTime.DateTime
                                Nome = $e.Name; Host = Get-MobaLogHost $nomeBase
                                Caminho = $f.FullName; Entrada = $e.FullName; Tamanho = $e.Length
                            }
                        }
                    } finally { $zip.Dispose() }
                } catch { }
            }
        }
    }
}

function Get-MobaLogHost([string]$Nome) {
    # formato antigo: SESSAO-USER-[@HOST]PORTA-(HORA)   formato novo: SESSAO_HOST_HORA
    if ($Nome -match '\[@([^\]]+)\]') { return $Matches[1] }
    $partes = $Nome -split '_'
    if ($partes.Count -ge 3) { return $partes[1] }
    return ''
}

function Read-MobaLog {
    # Le o log (arquivo ou entrada de zip) e devolve o texto LIMPO
    param([Parameter(Mandatory)]$Item)
    if ($Item.Entrada) {
        $zip = [IO.Compression.ZipFile]::OpenRead($Item.Caminho)
        try {
            $e = $zip.GetEntry($Item.Entrada)
            $ms = New-Object IO.MemoryStream
            $s = $e.Open(); try { $s.CopyTo($ms) } finally { $s.Dispose() }
            $bytes = $ms.ToArray()
        } finally { $zip.Dispose() }
    } else {
        # FileShare ReadWrite: funciona mesmo com a sessao ainda aberta gravando o log
        $fs = [IO.File]::Open($Item.Caminho, 'Open', 'Read', 'ReadWrite')
        try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); $bytes = $ms.ToArray() } finally { $fs.Dispose() }
    }
    return [MobaLogLimpo]::Limpar([MobaLogLimpo]::Decodificar($bytes))
}

function New-MobaLogRegex {
    param([string]$Texto, [switch]$Regex)
    $padrao = if ($Regex) { $Texto } else { [regex]::Escape($Texto) }
    return New-Object regex -ArgumentList $padrao, ([Text.RegularExpressions.RegexOptions]'IgnoreCase, Multiline')
}

function Find-MobaLogTexto {
    # Procura no nome e/ou no conteudo limpo. Devolve $null se nao achou, ou
    # Ocorrencias + Trecho (primeira linha encontrada)
    param($Item, [regex]$Rx, [switch]$NoNome, [switch]$NoConteudo)
    $noNomeAchou = $NoNome -and $Rx.IsMatch($Item.Nome)
    $total = 0; $trecho = ''
    if ($NoConteudo) {
        $texto = Read-MobaLog $Item
        $ms = $Rx.Matches($texto)
        $total = $ms.Count
        if ($total -gt 0) {
            $ini = $texto.LastIndexOf("`n", [Math]::Max(0, $ms[0].Index - 1)) + 1
            $fim = $texto.IndexOf("`r", $ms[0].Index); if ($fim -lt 0) { $fim = $texto.Length }
            $trecho = $texto.Substring($ini, [Math]::Min(200, $fim - $ini)).Trim()
        }
    }
    if (-not $noNomeAchou -and $total -eq 0) { return $null }
    if (-not $trecho -and $noNomeAchou) { $trecho = '(nome do arquivo)' }
    return [pscustomobject]@{ Ocorrencias = $total; Trecho = $trecho }
}
