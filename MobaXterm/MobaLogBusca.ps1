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

function Get-MobaLogPastasUnicas([string[]]$Pastas) {
    # Remove pastas repetidas (C:\Log e c:\log\ sao a mesma) e subpastas de outra pasta da
    # lista: senao os mesmos arquivos seriam lidos mais de uma vez
    $cheias = @($Pastas | Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
        ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\', '/') } | Sort-Object Length -Unique)
    $unicas = New-Object Collections.Generic.List[string]
    foreach ($p in $cheias) {
        $dentro = $false
        foreach ($u in $unicas) {
            if ($p.Equals($u, [StringComparison]::OrdinalIgnoreCase) -or
                $p.StartsWith($u + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
                $p.StartsWith($u + '/', [StringComparison]::OrdinalIgnoreCase)) { $dentro = $true; break }
        }
        if (-not $dentro) { $unicas.Add($p) }
    }
    return $unicas
}

function Test-MobaLogIgnorado([string]$Nome) {
    # Arquivos gerados pelas ferramentas (historico do organizador, logs limpos e diffs exportados)
    return ($Nome -eq '_organizador.log' -or $Nome -like '*.limpo.txt' -or $Nome -like 'diff_*.txt')
}

function Get-MobaLogArquivos {
    # Lista os logs (.log/.txt), inclusive dentro dos .zip de meses compactados.
    # Cada item: Data, Nome, Host, Caminho, Entrada (nome dentro do zip ou $null), Tamanho
    param([string[]]$Pastas, [string[]]$Extensoes = @('.log', '.txt'))
    try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop } catch { }
    foreach ($pasta in (Get-MobaLogPastasUnicas $Pastas)) {
        foreach ($f in Get-ChildItem -LiteralPath $pasta -Recurse -File -ErrorAction SilentlyContinue) {
            $ext = $f.Extension.ToLower()
            if (Test-MobaLogIgnorado $f.Name) { continue }
            if ($Extensoes -contains $ext) {
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
                            if (Test-MobaLogIgnorado $e.Name) { continue }
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

# ------------------------------------------------------------------ comparacao (diff)
if (-not ('MobaDiff' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

public class MobaBloco
{
    public string Comando; public string Chave; public int Linha; public string Texto;
    public override string ToString() { return string.Format("linha {0,-6} {1}", Linha, Comando); }
}

public class MobaLinhaDiff
{
    public char Tipo;          // ' ' igual, '-' so em A, '+' so em B, '@' separador
    public int LinhaA; public int LinhaB; public string Texto;
}

public static class MobaDiff
{
    // <HUAWEI>cmd  [~HUAWEI-GE0/0/1]cmd  user@mx> cmd  user@host:~$ cmd  R1#cmd  R1(config-if)#cmd  R1>cmd
    static readonly Regex Prompt = new Regex(
        @"^(<[^<>\s]+>|\[[~*]?[^\[\]\s]+\]|[\w.\-]+@[\w.\-]+(:[^\s]*)?[>#%$]|[\w.\-]+(\([^)\s]*\))?[#>])[ ]?(?<cmd>.*)$",
        RegexOptions.Compiled);

    static readonly string[] Palavras = {
        "current-configuration", "running-config", "startup-config", "saved-configuration", "configuration",
        "interface", "brief", "description", "routing-table", "version", "peer", "neighbor", "summary",
        "statistics", "verbose", "transceiver", "optical-module", "alarm", "active", "lldp", "arp", "mac-address",
        "vlan", "bgp", "ospf", "isis", "mpls", "ldp", "vpn-instance", "route", "access-user", "users" };

    // Chave para casar o mesmo comando escrito de formas diferentes: "dis cur" = "display current-configuration"
    public static string Chave(string cmd)
    {
        string c = Regex.Replace(cmd.Trim().ToLowerInvariant(), @"\s+", " ");
        c = Regex.Replace(c, @"\s*\|\s*no-more$", "");
        string[] t = c.Split(' ');
        if (t.Length == 0) return c;
        if (t[0].Length >= 2 && "display".StartsWith(t[0])) t[0] = "display";
        else if (t[0].Length >= 2 && "show".StartsWith(t[0])) t[0] = "show";
        if (t[0] == "display" || t[0] == "show")
            for (int i = 1; i < t.Length; i++)
            {
                if (t[i].Length < 2 || t[i] == "|") break;
                foreach (string p in Palavras) if (p.StartsWith(t[i])) { t[i] = p; break; }
            }
        return string.Join(" ", t);
    }

    public static List<MobaBloco> Blocos(string texto)
    {
        string[] linhas = Linhas(texto);
        List<MobaBloco> lista = new List<MobaBloco>();
        MobaBloco atual = null; StringBuilder sb = null;
        for (int i = 0; i < linhas.Length; i++)
        {
            Match m = Prompt.Match(linhas[i]);
            if (m.Success)
            {
                if (atual != null) { atual.Texto = sb.ToString(); lista.Add(atual); atual = null; }
                string cmd = m.Groups["cmd"].Value.Trim();
                if (cmd.Length == 0) continue;
                atual = new MobaBloco(); atual.Comando = cmd; atual.Chave = Chave(cmd); atual.Linha = i + 1;
                sb = new StringBuilder();
                continue;
            }
            if (atual != null) sb.Append(linhas[i]).Append("\r\n");
        }
        if (atual != null) { atual.Texto = sb.ToString(); lista.Add(atual); }
        return lista;
    }

    public static string[] Linhas(string texto)
    {
        string t = texto.Replace("\r\n", "\n");
        if (t.EndsWith("\n")) t = t.Substring(0, t.Length - 1);
        return t.Length == 0 ? new string[0] : t.Split('\n');
    }

    static string[] Normalizar(string[] l, bool numeros, bool espacos)
    {
        string[] r = new string[l.Length];
        for (int i = 0; i < l.Length; i++)
        {
            string s = l[i];
            if (espacos) s = Regex.Replace(s.Trim(), @"\s+", " ");
            if (numeros) s = Regex.Replace(s, @"\d+", "#");
            r[i] = s;
        }
        return r;
    }

    public static List<MobaLinhaDiff> Comparar(string textoA, string textoB, bool ignorarNumeros, bool ignorarEspacos, int limite)
    {
        string[] a = Linhas(textoA), b = Linhas(textoB);
        string[] ka = Normalizar(a, ignorarNumeros, ignorarEspacos), kb = Normalizar(b, ignorarNumeros, ignorarEspacos);
        int ini = 0;
        while (ini < a.Length && ini < b.Length && ka[ini] == kb[ini]) ini++;
        int fa = a.Length, fb = b.Length;
        while (fa > ini && fb > ini && ka[fa - 1] == kb[fb - 1]) { fa--; fb--; }

        List<MobaLinhaDiff> r = new List<MobaLinhaDiff>();
        for (int i = 0; i < ini; i++) r.Add(L(' ', i, i, b[i]));
        foreach (int[] op in Myers(ka, ini, fa - ini, kb, ini, fb - ini, limite))
        {
            if (op[0] == 0) r.Add(L(' ', op[1], op[2], b[op[2]]));
            else if (op[0] == 1) r.Add(L('-', op[1], -1, a[op[1]]));
            else r.Add(L('+', -1, op[2], b[op[2]]));
        }
        for (int i = 0; i < a.Length - fa; i++) r.Add(L(' ', fa + i, fb + i, b[fb + i]));
        return r;
    }

    static MobaLinhaDiff L(char tipo, int ia, int ib, string texto)
    {
        MobaLinhaDiff d = new MobaLinhaDiff();
        d.Tipo = tipo; d.LinhaA = ia + 1; d.LinhaB = ib + 1; d.Texto = texto;
        return d;
    }

    // Myers O((N+M)D). Guarda so a faixa usada de V a cada passo: memoria O(D^2).
    static List<int[]> Myers(string[] a, int a0, int n, string[] b, int b0, int m, int limite)
    {
        List<int[]> ops = new List<int[]>();
        int max = n + m;
        if (max == 0) return ops;
        int off = max + 1;
        int[] v = new int[2 * max + 3];
        List<int[]> trace = new List<int[]>();
        bool fim = false;
        for (int d = 0; d <= max && !fim; d++)
        {
            if (d > limite) throw new InvalidOperationException("Diferencas demais para comparar (mais de " + limite + "). Escolha um comando especifico.");
            int[] snap = new int[2 * d + 3];
            Array.Copy(v, off - (d + 1), snap, 0, 2 * d + 3);
            trace.Add(snap);
            for (int k = -d; k <= d; k += 2)
            {
                int x = (k == -d || (k != d && v[off + k - 1] < v[off + k + 1])) ? v[off + k + 1] : v[off + k - 1] + 1;
                int y = x - k;
                while (x < n && y < m && a[a0 + x] == b[b0 + y]) { x++; y++; }
                v[off + k] = x;
                if (x >= n && y >= m) { fim = true; break; }
            }
        }
        int cx = n, cy = m;
        for (int d = trace.Count - 1; d >= 0; d--)
        {
            int[] s = trace[d];
            int k = cx - cy;
            int pk = (k == -d || (k != d && s[k - 1 + d + 1] < s[k + 1 + d + 1])) ? k + 1 : k - 1;
            int px = s[pk + d + 1], py = px - pk;
            while (cx > px && cy > py) { ops.Add(new int[] { 0, a0 + cx - 1, b0 + cy - 1 }); cx--; cy--; }
            if (d > 0)
            {
                if (cx == px) ops.Add(new int[] { 2, -1, b0 + cy - 1 });
                else ops.Add(new int[] { 1, a0 + cx - 1, -1 });
            }
            cx = px; cy = py;
        }
        ops.Reverse();
        return ops;
    }

    // Linhas a mostrar: tudo (contexto < 0) ou so mudancas com N linhas de contexto e separadores '@'
    public static List<MobaLinhaDiff> Visiveis(List<MobaLinhaDiff> d, int contexto)
    {
        if (contexto < 0) return d;
        int n = d.Count;
        bool[] mostrar = new bool[n];
        for (int i = 0; i < n; i++)
            if (d[i].Tipo != ' ')
                for (int j = Math.Max(0, i - contexto); j <= Math.Min(n - 1, i + contexto); j++) mostrar[j] = true;
        List<MobaLinhaDiff> r = new List<MobaLinhaDiff>();
        bool pulou = true;
        for (int i = 0; i < n; i++)
        {
            if (!mostrar[i]) { pulou = true; continue; }
            if (pulou)
            {
                MobaLinhaDiff sep = new MobaLinhaDiff(); sep.Tipo = '@';
                sep.LinhaA = d[i].LinhaA; sep.LinhaB = d[i].LinhaB; r.Add(sep);
                pulou = false;
            }
            r.Add(d[i]);
        }
        return r;
    }

    static string Prefixo(MobaLinhaDiff l)
    {
        if (l.Tipo == '@')
            return "@@ A linha " + (l.LinhaA > 0 ? l.LinhaA.ToString() : "-") + " | B linha " + (l.LinhaB > 0 ? l.LinhaB.ToString() : "-") + " @@";
        return string.Format("{0,5} {1,5} {2} ", l.LinhaA > 0 ? l.LinhaA.ToString() : "", l.LinhaB > 0 ? l.LinhaB.ToString() : "", l.Tipo);
    }

    public static string ParaTexto(List<MobaLinhaDiff> linhas)
    {
        StringBuilder sb = new StringBuilder();
        foreach (MobaLinhaDiff l in linhas) sb.Append(Prefixo(l)).Append(l.Tipo == '@' ? "" : l.Texto).Append("\r\n");
        return sb.ToString();
    }

    public static string ParaRtf(List<MobaLinhaDiff> linhas)
    {
        StringBuilder sb = new StringBuilder();
        sb.Append(@"{\rtf1\ansi\deff0{\fonttbl{\f0\fmodern Consolas;}}");
        sb.Append(@"{\colortbl;\red200\green200\blue200;\red255\green105\blue105;\red110\green225\blue110;\red90\green190\blue255;\red120\green120\blue120;}");
        sb.Append(@"\f0\fs20 ");
        foreach (MobaLinhaDiff l in linhas)
        {
            int cor = l.Tipo == '-' ? 2 : l.Tipo == '+' ? 3 : l.Tipo == '@' ? 4 : 5;
            sb.Append(@"\cf").Append(cor).Append(' ');
            Escapar(sb, Prefixo(l));
            if (l.Tipo != '@') { if (l.Tipo == ' ') sb.Append(@"\cf1 "); Escapar(sb, l.Texto); }
            sb.Append("\\par\r\n");
        }
        sb.Append('}');
        return sb.ToString();
    }

    static void Escapar(StringBuilder sb, string s)
    {
        foreach (char c in s)
        {
            if (c == '\\' || c == '{' || c == '}') sb.Append('\\').Append(c);
            else if (c == '\t') sb.Append(@"\tab ");
            else if (c > 127) sb.Append(@"\u").Append((int)(short)c).Append('?');
            else sb.Append(c);
        }
    }
}
'@
}

function Compare-MobaLog {
    # Compara dois textos (logs inteiros ou saidas de um comando). Devolve Linhas, Adicionadas, Removidas
    param([string]$TextoA, [string]$TextoB, [switch]$IgnorarNumeros, [switch]$IgnorarEspacos, [int]$Limite = 5000)
    $d = [MobaDiff]::Comparar($TextoA, $TextoB, [bool]$IgnorarNumeros, [bool]$IgnorarEspacos, $Limite)
    [pscustomobject]@{
        Linhas      = $d
        Removidas   = @($d | Where-Object { $_.Tipo -eq [char]'-' }).Count
        Adicionadas = @($d | Where-Object { $_.Tipo -eq [char]'+' }).Count
    }
}

function Get-MobaLogBlocos([string]$Texto) {
    # Blocos "prompt + comando + saida" do log limpo
    return , [MobaDiff]::Blocos($Texto)
}

function Get-MobaLogChaveEquipamento($Item) {
    # Identifica o equipamento para achar o log anterior: host, ou nome da sessao
    if ($Item.Host) { return $Item.Host.ToLower() }
    $base = [IO.Path]::GetFileNameWithoutExtension($Item.Nome)
    return (($base -split '[_(\[]')[0].TrimEnd('-', ' ')).ToLower()
}

# ------------------------------------------------------------------ data/hora por linha
# O MobaXterm pode gravar "[2026-09-25 02:41:49.217] " no inicio de cada linha.
$script:RxDataHora = New-Object regex -ArgumentList '(?m)^\[\d{2,4}[-/.]\d{1,2}[-/.]\d{2,4}[ T]\d{1,2}:\d{2}:\d{2}(?:[.,]\d+)?\] ?', 'Compiled'

function Remove-MobaLogDataHora([string]$Texto) {
    # Tira a data/hora do inicio das linhas (para ler melhor e para comparar logs)
    return $script:RxDataHora.Replace($Texto, '')
}
