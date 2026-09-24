# MobaXterm – logs por data, sync pelo OneDrive e cores para redes

Scripts PowerShell (Windows PowerShell 5.1 ou PowerShell 7) para:

1. **Organizar os logs** do MobaXterm em pastas `Ano\Mês\Dia`, automaticamente ao abrir/fechar o Moba.
2. **Sincronizar as sessões** entre o PC do trabalho e o de casa pelo **OneDrive**.
3. **Colorir o terminal** para Cisco, Huawei e Juniper.

| Arquivo | Para que serve |
|---|---|
| `config.psd1` | **Única coisa que você edita**: caminho do Moba, pasta de logs, retenção etc. |
| `Organizar-LogsMoba.ps1` | Move os logs para `2026\09-Setembro\24\...` |
| `Iniciar-MobaXterm.ps1` | Organiza os logs → abre o Moba → organiza de novo quando o Moba fecha |
| `Instalar-MobaTools.ps1` | Cria o atalho **"MobaXterm (logs)"** e (opcional) uma tarefa agendada |
| `Configurar-SyncOneDrive.ps1` | Coloca o `MobaXterm.ini` (sessões) no OneDrive |
| `Syntax-Redes.ini` + `Instalar-SyntaxRedes.ps1` | Perfil de cores "Custom: Redes (Cisco/Huawei/Juniper)" |

> Dica: coloque esta pasta de scripts dentro do OneDrive — assim ela já fica igual nos dois PCs.

---

## 1. Logs organizados por data

### Pré-requisito no MobaXterm
`Settings > Configuration > Terminal` → marque **"Log terminal output to the following directory"** e escolha a pasta.

O formato do nome do log fica em *Log file name format*. O padrão `&S-&U-[@&H]&P-(&T)` (sessão-usuário-host-porta-horário) funciona bem: o script usa **a última data que aparece no nome** (o `&T`). Se o nome não tiver data, ele usa a data de modificação do arquivo.

### Instalação

```powershell
# 1x só, se o Windows bloquear scripts:
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# se baixou os arquivos da internet/zip:
Get-ChildItem .\*.ps1 | Unblock-File

# teste sem mover nada
.\Organizar-LogsMoba.ps1 -WhatIf

# cria o atalho "MobaXterm (logs)" na Área de Trabalho e no Menu Iniciar
# + tarefa agendada que organiza no logon e a cada 1 hora
.\Instalar-MobaTools.ps1 -TarefaAgendada -IntervaloHoras 1
```

Depois **fixe o atalho "MobaXterm (logs)" na barra de tarefas** no lugar do atalho original. Pronto: toda vez que você abrir o Moba por ele, os logs são organizados (e de novo quando você fechar).

Resultado:

```
Log\
├─ _organizador.log                       ← histórico do que foi movido
├─ 2026\
│  ├─ 08-Agosto\15\NE-BNG-...-(20260815_101500).log
│  └─ 09-Setembro\24\SONIC-...-(2026-09-24_17-02-10).log
└─ SESSAO-ABERTA-....log                  ← em uso: fica aqui até fechar
```

### Opções (em `config.psd1`)
- `PastaLogs = ''` → descobre sozinho lendo `LogFolder=` do `MobaXterm.ini` (entende `_MobaFolder_`, `_AppDataDir_` etc.).
- `PastaDestino` → ex.: `'%OneDrive%\MobaXterm\Logs'` para ter os logs em casa também.
- `MinutosIgnorar` → não mexe em logs alterados há menos de N minutos (sessão aberta). Arquivos travados também são ignorados.
- `CompactarAposMeses` → vira `2026\03-Marco.zip` depois de N meses.
- `ApagarAposDias` → retenção (0 = nunca apaga).
- Nomes repetidos nunca são sobrescritos (`arquivo_1.log`, `arquivo_2.log`...).

Remover atalhos e tarefa: `.\Instalar-MobaTools.ps1 -Remover`

---

## 2. Sessões iguais no trabalho e em casa (OneDrive)

Tudo (sessões, pastas, macros, senhas salvas, cores) fica em **um arquivo: `MobaXterm.ini`**. A ideia é manter esse arquivo no OneDrive. Três jeitos, do mais simples ao mais "manual":

### Opção A (recomendada) – MobaXterm **Portable** dentro do OneDrive
Na versão portable o `MobaXterm.ini` fica **na mesma pasta do .exe**. Colocando a pasta no OneDrive, os dois PCs usam o mesmo Moba, as mesmas sessões e (com `LogFolder=_MobaFolder_\Log`) os mesmos logs.

1. No PC do trabalho: *Settings > Configuration > General > Export configuration* (backup).
2. Baixe o **MobaXterm Portable** (mesma versão), extraia em `%OneDrive%\MobaXterm\`.
3. Copie o seu `MobaXterm.ini` atual (normalmente `Documentos\MobaXterm\MobaXterm.ini`) para essa pasta, ao lado do `.exe`. Os plugins (`.mxt3`) também vão ao lado do `.exe`.
4. No OneDrive, clique com o botão direito na pasta → **"Sempre manter neste dispositivo"**.
5. Em `config.psd1`: `MobaExe = '%OneDrive%\MobaXterm\MobaXterm_Personal_XX.X.exe'` e `MobaIni = ''`.
6. Rode `.\Instalar-MobaTools.ps1` nos dois PCs.

> `HomeDir`/`SlashDir` apontando para `_AppDataDir_` ficam **fora** do OneDrive (bom: são milhares de arquivos pequenos que não precisam sincronizar).

### Opção B – Continuar com o instalado e usar `MobaXterm.exe -i <ini do OneDrive>`
```powershell
# PC do trabalho (Moba FECHADO):
.\Configurar-SyncOneDrive.ps1 -Modo Enviar
# espere o OneDrive subir o arquivo; no PC de casa (Moba FECHADO):
.\Configurar-SyncOneDrive.ps1 -Modo Receber
.\Instalar-MobaTools.ps1
```
O script faz backup do ini, copia para `%OneDrive%\MobaXterm\MobaXterm.ini` e grava esse caminho em `config.psd1`; o atalho "MobaXterm (logs)" abre o Moba com `-i`. Com `-Metodo Symlink` ele troca o ini local por um link simbólico (funciona com qualquer atalho; precisa de admin ou Modo de Desenvolvedor).

### Opção C – "Shared sessions" nativo do Moba
`Settings > Manage shared sessions` → aponta para um arquivo numa pasta compartilhada (pode ser no OneDrive). Bom para **compartilhar só as sessões** (ex.: com a equipe), mas não leva senhas, macros e configurações.

### Cuidados (valem para A e B)
- **Nunca deixe o Moba aberto nos dois PCs ao mesmo tempo.** Ele regrava o ini ao fechar: o último a fechar vence, e o OneDrive pode criar `MobaXterm-NOMEDOPC.ini` (conflito). Se aparecer, compare e apague o que sobrar.
- Sessão nova criada em um PC só aparece no outro depois de **fechar e reabrir** o Moba.
- **Senhas salvas**: use **master password** e a mesma nos dois PCs. Na primeira abertura no PC novo o Moba vai pedir a master password. Se ele não conseguir abrir as senhas salvas, cadastre de novo naquele PC (ou, melhor, use chave SSH).
- Mantenha `BackupIni=1` (*Settings > General*) – o Moba guarda cópias do ini.

---

## 3. Terminal colorido para Cisco / Huawei / Juniper

```powershell
# com o Moba FECHADO
.\Instalar-SyntaxRedes.ps1          # adiciona [CustomSyntaxN] "Custom: Redes (Cisco/Huawei/Juniper)"
.\Instalar-SyntaxRedes.ps1 -Slot 3  # alternativa: substitui o "Custom: Cisco (network)" nativo
```

Depois escolha o perfil em **Settings > Configuration > Terminal > Syntax highlighting** (padrão para sessões novas) e, nas sessões existentes, em *Edit session > Terminal settings > Syntax highlighting* (dá para selecionar várias sessões e editar de uma vez).

Um perfil só cobre os três fabricantes (o Moba aplica **um** perfil por sessão). O que ele destaca (as cores seguem o esquema dos perfis nativos do Moba):

| Grupo | Exemplos |
|---|---|
| Problema | `down`, `*down`, `administratively`, `err-disabled`, `Idle`, `error`, `crc`, `drops`, `timeout`, `unreachable`, linhas que começam com `no` / `undo` / `delete` / `deactivate` |
| OK | `up`, `Established`, `FULL`, `forwarding`, `enabled`, `active`; linhas `description`, `hostname`, `sysname`, `host-name` |
| Endereços / interfaces | IPv4 (com /máscara), IPv6, MAC (3 formatos), VLAN/Vlanif, `Gi0/0/1`, `TenGigabitEthernet1/1`, `Po10`, `GE0/3/0`, `100GE1/0/1`, `Eth-Trunk10`, `ge-0/0/0.0`, `xe-`, `et-`, `ae0`, `irb.100`, `lo0` |
| Comentários | linhas `!` (Cisco) e `#` (Huawei/Juniper) |
| Blocos de config | `interface`, `bgp`, `ospf`, `isis`, `mpls`, `vpn-instance`, `route-policy`, `policy-statement`, `protocols`, `routing-instances`, `firewall`... |
| Comandos | `show`, `display`, `dis`, `ping`, `tracert`, `system-view`, `commit`, `rollback`, `save`, `set`... |
| Prompts | `R1#`, `R1(config-if)#`, `<HUAWEI>`, `[~HUAWEI-GE0/0/1]`, `user@mx>`, `[edit protocols bgp]` |

Quer ajustar? Edite as regex no próprio Moba (*Settings > Terminal > Syntax highlighting > editar*) ou em `Syntax-Redes.ini` e rode o instalador de novo. O arquivo está em Latin-1: o caractere `¨` marca início/fim de linha nas regex do Moba.

---

## 4. Melhorias que valem a pena no MobaXterm

**Produtividade**
- **MultiExec** (botão na barra): digita o mesmo comando em vários equipamentos ao mesmo tempo (ex.: `display bgp peer` em todos os NE).
- **Macros** (*Tools > Macros*): grave sequências (`screen-length 0 temporary`, `terminal length 0`, `set cli screen-length 0`) e rode com um clique ou `MobaXterm.exe -runmacro "nome"`.
- **Abrir sessão direto**: `MobaXterm.exe -bookmark "NOME-DA-SESSAO"` – dá para criar atalhos só para os equipamentos mais usados (`.\Iniciar-MobaXterm.ps1 -bookmark "NOME"` também funciona).
- **Pastas e ícones** nas sessões (por cliente/POP/fabricante).
- **Split / tile** de terminais para acompanhar dois equipamentos lado a lado.
- **Túneis SSH** (*Tunneling*) salvos para acessar gerência/HTTPS atrás de um jump host.
- **Popup terminal** (`Ctrl+Alt+M` por padrão) para comandos rápidos.
- Aumente o buffer: `ScrollbackLines` em `[Misc]` (ex.: `ScrollbackLines=100000`) para `display current-configuration` longos.

**Logs**
- Use o formato de nome com sessão, host e horário (`&S-&U-[@&H]&P-(&T)`) – é o que permite achar o log certo depois.
- Timestamp por linha (*Settings > Terminal*) ajuda muito em janela de manutenção.
- Logs podem ter caracteres de controle; o **MobaTextEditor** limpa, ou use `Get-Content` + regex.

**Segurança**
- Mantenha **master password** ligada e prefira **chave SSH** a senha salva.
- Deixe a checagem de host key ativa (*Settings > SSH*) para ser avisado se a chave de um equipamento mudar.
- Ative o aviso ao colar várias linhas (*Settings > Terminal*) – evita colar config no equipamento errado.
- Limpe senhas antigas em *Settings > General > MobaXterm passwords management*.
- Não compartilhe o `.mobaconf`/`MobaXterm.ini` completo: ele leva as senhas salvas (criptografadas).

**Manutenção**
- Mesma versão do Moba nos dois PCs (o formato do ini muda entre versões).
- *Settings > General > Export configuration* de vez em quando, como backup extra.

### Fontes
- [MobaXterm – documentação oficial (parâmetros de linha de comando, logs, shared sessions)](https://mobaxterm.mobatek.net/documentation.html)
- [Mobatek blog – MobaXterm configuration settings](https://blog.mobatek.net/post/mobaxterm-configuration-settings/)
- [Mobatek blog – How to configure the shared sessions](https://blog.mobatek.net/post/configure-shared-sessions/)
- [Mobatek blog – novidades da versão 10 (popup terminal, atalhos)](https://blog.mobatek.net/post/mobaxterm-new-release-10.0/)
- [Syncing your SSH/RDP sessions with Dropbox and MobaXterm](https://grumpyneteng.com/syncing-your-sshrdp-sessions-with-dropbox-and-mobaxterm/)
