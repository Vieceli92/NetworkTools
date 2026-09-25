# MobaXterm – logs por data, sync pelo OneDrive e cores para redes

Scripts PowerShell (Windows PowerShell 5.1 ou PowerShell 7) para:

1. **Organizar os logs** do MobaXterm em pastas `Ano\Mês\Dia`, automaticamente ao abrir/fechar o Moba.
2. **Sincronizar as sessões** entre o PC do trabalho e o de casa pelo **OneDrive**.
3. **Colorir o terminal** para Cisco, Huawei e Juniper.
4. **Anti-idle**: manter as sessões abertas mesmo com `exec-timeout`/`idle-timeout` no equipamento.

> **Baixe a pasta `MobaXterm` inteira** (GitHub > *Code* > *Download ZIP*, na branch certa). Os scripts dependem
> de `MobaTools.Common.ps1` e `config.psd1`, e copiar e colar o texto costuma corromper o arquivo
> (o resultado é o erro `'}' de fechamento ausente`).

| Arquivo | Para que serve |
|---|---|
| `config.psd1` | **Única coisa que você edita**: caminho do Moba, pasta de logs, retenção etc. |
| `Organizar-LogsMoba.ps1` | Move os logs para `2026\09-Setembro\24\...` |
| `Pesquisar-Logs.ps1` + `MobaLogBusca.ps1` | **Janela de busca e comparação (diff) dos logs**, com prévia do log limpo |
| `Pesquisar Logs.cmd` / `Criar Atalhos.cmd` | **Dois cliques**: abre a janela de busca / cria os ícones na Área de Trabalho e baixa o AutoHotkey |
| `Diagnosticar-MobaTools.ps1` / **`Diagnostico.cmd`** | **Confere tudo** (Moba, ini, logs, cores, AutoHotkey, atalhos) e mostra o que está errado; não altera nada |
| `Atualizar-MobaTools.ps1` / **`Atualizar.cmd`** | **Atualiza esta pasta** com a versão mais nova do GitHub (mantém o seu `config.psd1`) |
| `Instalar-AutoHotkey.ps1` / `Instalar AntiIdle.cmd` | Baixa o AutoHotkey v2 portátil (`AutoHotkey64.exe`) para a pasta `AntiIdle` |
| `Iniciar-MobaXterm.ps1` | Organiza os logs → abre o Moba → organiza de novo quando o Moba fecha |
| `Instalar-MobaTools.ps1` | Cria o atalho **"MobaXterm (logs)"** e (opcional) uma tarefa agendada |
| `Configurar-SyncOneDrive.ps1` | Coloca o `MobaXterm.ini` (sessões) no OneDrive |
| `Ajustar-MobaIni.ps1` | Nome de log limpo (`&S_&H_&T`), sessões sem " (usuário)", X server iniciando junto, SSH sem GSSAPI |
| `Migrar-ParaPortable.ps1` | Migra o Moba instalado para o **portable no OneDrive** (ini, logs, plugins, atalho) |
| `Syntax-Redes.ini` + `Instalar-SyntaxRedes.ps1` | Perfis de cores "Custom: Redes" (completo e compacto). Gerados por `tools/gerar_syntax.py` |
| `AntiIdle\MobaAntiIdle.ahk` | **Anti-idle** estilo SecureCRT (a sessão não cai por `idle-timeout`) |

> Dica: coloque esta pasta de scripts dentro do OneDrive — assim ela já fica igual nos dois PCs.

---

## Passo a passo rápido

Sempre com o **MobaXterm fechado**, inclusive o ícone perto do relógio.

**PC do trabalho (primeira vez)**
1. Baixe o zip, clique com o botão direito > Propriedades > **Desbloquear**, e extraia em `%OneDrive%\Documents\MobaXterm\Scripts\`.
2. No PowerShell, dentro da pasta:
   ```powershell
   Get-ChildItem -Recurse | Unblock-File
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
   .\Migrar-ParaPortable.ps1 -TarefaAgendada   # portable no OneDrive + atalho "MobaXterm (logs)"
   .\Ajustar-MobaIni.ps1                       # nome de log, sessões, X server, SSH
   .\Instalar-SyntaxRedes.ps1                  # cores
   ```
3. Abra o Moba pelo atalho **"MobaXterm (logs)"** e escolha o perfil em *Settings > Terminal > Syntax highlighting*.
4. Para achar ou comparar logs: dois cliques em **`Pesquisar Logs.cmd`**. Para ter os ícones na Área de Trabalho: dois cliques em **`Criar Atalhos.cmd`**.

**PC de casa**
1. Espere o OneDrive sincronizar a pasta `Documents\MobaXterm` e marque **"Sempre manter neste dispositivo"**.
2. Rode só `.\Migrar-ParaPortable.ps1 -TarefaAgendada`. Ele usa o ini que veio pelo OneDrive; os ajustes e as cores já vêm junto.
3. Na primeira abertura, use a mesma master password. Chaves SSH: copie `%APPDATA%\MobaXterm\home\.ssh` do trabalho.
4. Anti-idle: instale o AutoHotkey v2 (ou coloque o `AutoHotkey64.exe` na pasta `AntiIdle`).

**Atualizando os scripts:** dois cliques em **`Atualizar.cmd`**. Ele:
- baixa a versão mais nova do GitHub e copia por cima da pasta;
- **mantém o seu `config.psd1`**, acrescentando opções novas com o valor padrão;
- não mexe no AutoHotkey nem nos logs, e desbloqueia os arquivos;
- se já estiver atualizado, avisa e não baixa nada (`versao.txt` guarda a versão instalada).

Se mudaram as cores (`Syntax-Redes.ini`), rode também `Instalar-SyntaxRedes.ps1` com o Moba fechado.

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

### Pesquisar e comparar logs (janela)
Dois cliques em **`Pesquisar Logs.cmd`**, ou no ícone **"Pesquisar logs Moba"**. Os ícones são criados com dois cliques em **`Criar Atalhos.cmd`**.

**Pesquisar**
- Digite um **hostname, IP ou qualquer texto** e tecle Enter. A busca é no **nome** e/ou **dentro** do log, inclusive nos `.zip` de meses compactados. Marque **Regex** para buscas como `NE40-.*ERM`.
- **De / Até** filtra por data (pastas `Ano\Mês\Dia`, nome do log ou data do arquivo).
- Clique num resultado para ver o log **limpo**, com as ocorrências destacadas. `F3` / `Shift+F3` navega entre elas.
- **Ocultar / Mostrar data/hora** tira ou põe o `[2026-09-25 02:41:49.217]` do começo das linhas. Abrir, salvar, copiar e exportar usam o que estiver na tela.
- **Abrir limpo** (Bloco de Notas, também com duplo clique), **Salvar limpo...**, **Exportar limpos...** (todos da lista, numa subpasta por equipamento: `NE40-BGP\2026-09-24_....limpo.txt`), **Abrir pasta**, **Copiar tudo**.

**Comparar (o que mudou entre datas)**
1. Pesquise o **hostname ou IP** do equipamento, para listar todos os logs dele.
2. Escolha uma das formas:
   - selecione **2 logs** (Ctrl+clique) e clique em **Comparar**;
   - selecione **1 log** e clique em **Comparar com anterior**, que pega sozinho o log anterior do mesmo equipamento.
3. Na janela de comparação, escolha **o mesmo comando** nos dois logs ou **(log inteiro)**. Ela já abre na config (`display current-configuration` / `show running-config`) se existir nos dois. Formas abreviadas são reconhecidas como o mesmo comando: `dis cur` = `display current-configuration`, `sh run` = `show running-config`, `dis int br` = `display interface brief`.
   A data/hora do começo das linhas é sempre ignorada na comparação; senão todas as linhas seriam diferentes.
4. O resultado mostra linhas **removidas em vermelho** (`-`) e **adicionadas em verde** (`+`), com o número da linha em A e em B.
   - **Ignorar números** esconde mudanças de contadores, uptime e percentuais; sobra só o que mudou de estado.
   - **Ignorar espaços** desconsidera diferenças de espaçamento.
   - **Só as mudanças** mostra 3 linhas de contexto; desmarque para ver o texto todo.
5. **Salvar diff...** / **Abrir no Bloco de Notas** salvam a comparação em texto.

**O que a limpeza faz:** reconstrói o texto como ele apareceu na tela:
- aplica `\r`, backspace (correções de digitação) e os comandos de cursor/apagar do terminal;
- remove cores e códigos de controle;
- tira os restos de paginação: `---- More ----` (Huawei), `--More--` (Cisco), `---(more)---` (Juniper).

O arquivo original nunca é alterado. O limpo vai para `%TEMP%\MobaLogs` ou para onde você salvar.

### Formato do nome do log
`.\Ajustar-MobaIni.ps1` (com o Moba fechado) faz estes ajustes:
- troca `&S-&U-[@&H]&P-(&T)` por **`&S_&H_&T`**: sessão_host_horário, sem `[ ] ( ) @` e sem espaços. Colchetes quebram comandos do PowerShell, e o usuário e a porta estavam repetidos;
- renomeia sessões `NOME (usuario)` para `NOME`, só se não existir outra sessão com o mesmo nome na pasta;
- deixa ligado o X server na abertura do Moba (`XAuto=1`) e desliga o GSSAPI/Kerberos no SSH (`UseGSSAPI=0`, que só atrasa o login em roteador).

Também funciona num `.mobaconf` exportado: `-Ini arquivo.mobaconf -Saida ajustado.mobaconf`. `-SoLogs` faz só a parte de log. `-WhatIf` mostra o que mudaria.

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

#### Migração automática (instalado → portable)
Com o Moba **fechado**, dentro da pasta dos scripts:
```powershell
.\Migrar-ParaPortable.ps1 -WhatIf            # só mostra o que faria
.\Migrar-ParaPortable.ps1 -TarefaAgendada    # migra de verdade
# padrão: portable em %OneDrive%\Documents\MobaXterm  (outra pasta: -PastaPortable 'D:\...')
```
O script:
1. Confere se o Moba está fechado, acha o `.exe` do portable e compara a versão com a do instalado.
2. Faz **backup de todos os `MobaXterm.ini`** que encontrar (`_backup_migracao_AAAAMMDD_HHMMSS`).
3. Se já existir um ini na pasta do portable (ex.: sua pasta Documentos já está no OneDrive), **mantém** esse ini. Senão, copia o mais recente do instalado. Para escolher outro, use `-IniOrigem <caminho>`.
4. Ajusta os logs: `LogFolder=_MobaFolder_\Log` (a pasta Log fica ao lado do `.exe`), liga o log e troca caminhos fixos antigos dentro das sessões. `-CopiarLogsAntigos` também leva os logs antigos.
5. Copia os plugins `.mxt3`, marca a pasta como "Sempre manter neste dispositivo" e avisa se houver arquivos em conflito do OneDrive.
6. Atualiza o `config.psd1` e recria o atalho **"MobaXterm (logs)"**.

No PC de casa, rode o mesmo script depois que o OneDrive sincronizar.

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
.\Instalar-SyntaxRedes.ps1              # slots livres (4 e 5), sem mexer nos exemplos do Moba
.\Instalar-SyntaxRedes.ps1 -Slots 6,7    # alternativa: escolher os slots
```

São dois perfis:
- **"Custom: Redes (Cisco/Huawei/Juniper)"**: o completo.
- **"Custom: Redes compacto"**: todas as regras com até 690 caracteres, o mesmo tamanho das que vêm no Moba. Use este se o completo não colorir: o Moba pode ter limite de tamanho, e não consegui confirmar.

Depois escolha o perfil em **Settings > Configuration > Terminal > Syntax highlighting** (padrão para sessões novas) e, nas sessões existentes, em *Edit session > Terminal settings > Syntax highlighting* (dá para selecionar várias sessões e editar de uma vez).

**Inspirado no SecureCRT.** As regras foram adaptadas dos perfis de *keyword highlighting* mais usados por engenheiros de rede no SecureCRT: [feralpacket](https://github.com/feralpacket/securecrt-keyword-highlighting) (erro só quando o contador é ≠ 0, prompt de config destacado, syslog por severidade, reliability/txload, RT/RD) e [netOS-cli](https://github.com/h-lopez/netOS-cli) (`u/u`, `A/D`, formatos de MAC). Os arquivos `.ini` do SecureCRT **não funcionam direto no Moba**: o SecureCRT aceita dezenas de regras, cada uma com sua cor, e o Moba tem **8 grupos com cores fixas**. Então as regras foram reagrupadas por significado (ruim, bom, endereço...).

Um perfil só cobre os três fabricantes (o Moba aplica **um** perfil por sessão). O que ele destaca (as cores seguem o esquema dos perfis nativos do Moba):

O Moba tem **8 grupos de regras, cada um com uma cor fixa**: Sublinhado, Vermelho, Verde, Amarelo, Azul, Magenta, Ciano e Piscando (veja em *Settings > Terminal > Customize*). Não dá para escolher a cor de cada regra como no SecureCRT. A distribuição, com foco em **Huawei**:

| Cor | O que pinta | Exemplos |
|---|---|---|
| **Azul** | **prompt (nome do equipamento) + comando** | `<NE40-BGP>display bgp peer`, `R1#show ...`, `user@mx> show ...` |
| **Vermelho** | estados ruins | `*down`, `Idle`, `Unselect`, `Abnormal`, `Offline`, `Unregistered`, `err-disabled`, `error`, `timeout`, `A/D`, `u/D`, flags `(b)`, `(d)`, `(E)`, `(s)`, `(D)` |
| | contadores **≠ 0** | `152 input errors`, `37 CRC`, `Total Error: 12` (com `0 CRC` não pinta) |
| | limites | uso ≥ 90%, luz óptica ≤ -25 dBm, `reliability` < 255, `txload` ≥ 230/255 |
| | syslog 0-3, `undo`/`no`, diff `-` | `%%01IFNET/2/...`, `%LINK-3-UPDOWN` |
| | **prompt em modo config** | `[~NE40]`, `[*NE40]` (sem commit), `R1(config-if)#`, `user@mx#`, `[edit ...]` |
| **Verde** | estados bons | `up`, `Established`, `Full`, `Master`, `Selected`, `Normal`, `Registered`, `Operational`, `u/u`, `(P)`, `(SU)`; linhas `description`/`sysname`; diff `+` |
| **Amarelo** | **endereços IP** | IPv4/IPv6 (com máscara) e as linhas `ip address ...`, `ipv6 address ...`, `ip binding ...`, `ip route-static ...` |
| | atenção | BGP `Active`/`Connect`/`OpenSent`, OSPF `Init`/`ExStart`/`Loading`, LDP `Initialized`, `Standby`, `Backup`, `Passive`, `mismatch`, `flapping`, uso de 70-89%, luz de -20 a -25 dBm, syslog severidade 4 |
| **Magenta** | **MPLS / VPLS / L2VPN / L3VPN** | `mpls ldp`, `mpls l2vc`, `vsi`, `pw-template`, `evpn`, `vpn-instance`, `vpn-target 65001:100`, `route-distinguisher ...`, LDP ID `45.6.29.1:0`, `imp-null`, `sr-mpls`, `srv6` |
| **Ciano** | interfaces e MAC | MAC, `GE0/3/0`, `XGE`, `100GE1/0/1`, `Eth-Trunk10`, `Vlanif100`, `Global-VE`, `Gi0/0/1`, `ge-0/0/0.0`, `AS65001` |
| Sublinhado | protocolos e blocos | `interface`, `bgp`, `ospf`, `isis`, `static`, `ibgp`/`ebgp`, `route-policy`, `acl`, `qos`, `pppoe`, `bas`, `radius`, `ip pool`, `vrrp`, `bfd` |
| Piscando | (vazio) | |

**Instalação:** o Moba tem **8 slots** de perfil. Os slots 1-3 trazem exemplos do Moba e não são mexidos. Os perfis "Custom: Redes..." vão para os slots livres (normalmente 4 e 5), ou são atualizados onde já estiverem. Se uma versão anterior substituiu os exemplos "Cisco (network)"/"Unix shell", dá para recriá-los no Moba: *Customize > Import "network" / "shell" syntax definition*.

**Azul mais forte:** o tom vem da paleta do terminal (*Settings > Terminal > Default color settings > Blue*).

O perfil **compacto** deixa de fora: IPv6, `reliability`/`txload`/`Input queue` e alguns sinônimos.

Limitações:
- `Active` fica em **atenção**, porque no BGP é ruim mas aparece em saídas normais (`10 active routes`).
- O prompt do Huawei VRP5 sem `~`/`*` (`[HUAWEI]`) não é tratado como modo config.

Ideias de cores adaptadas do SecureCRT: [feralpacket](https://feralpacket.org/?p=817) e [netOS-cli](https://github.com/h-lopez/netOS-cli).

**Atenção ao editar:** o Moba separa os padrões de cada cor por **vírgula**. Nunca use `{n,m}` nem vírgula nas regras, senão a cor inteira para de funcionar.

Quer ajustar? Edite as regex no próprio Moba (*Settings > Terminal > Syntax highlighting > editar*) ou em `Syntax-Redes.ini` e rode o instalador de novo. O arquivo está em Latin-1: o caractere `¨` marca início/fim de linha nas regex do Moba.

---

## 4. Anti-idle (a sessão não cai por inatividade)

O MobaXterm só tem o **SSH keepalive** (*Settings > SSH > SSH keepalive*, que já está ligado na sua config). Ele manda pacotes do protocolo SSH, o que segura firewall e NAT, mas **não conta como tecla digitada**. Por isso o `exec-timeout` (Cisco), o `idle-timeout` (Huawei) e o `idle-timeout` (Juniper) derrubam a sessão do mesmo jeito. O SecureCRT resolve isso mandando caracteres ("anti-idle"). O `AntiIdle\MobaAntiIdle.ahk` faz o mesmo:

- A cada 240 s manda **Espaço + Backspace** para o terminal do Moba. Não apaga o que você já digitou.
- Não envia na janela em que você está digitando naquele momento.
- Ícone na bandeja: pausar, enviar agora, status. Atalho `Ctrl+Alt+Shift+A` liga e pausa.
- Fecha sozinho quando o Moba fecha.

**Instalação**
1. Dois cliques em **`Instalar AntiIdle.cmd`** (ou `Criar Atalhos.cmd`, que também faz isso). Ele baixa o [AutoHotkey v2](https://www.autohotkey.com) portátil e coloca o `AutoHotkey64.exe` na pasta `AntiIdle`, que vai pelo OneDrive para os dois PCs. Instalar o AutoHotkey normalmente também funciona.
2. Em `config.psd1`: `AntiIdle = $true` e `AntiIdleSegundos = 240` (use menos que o timeout do equipamento).
3. Abra o Moba pelo atalho **"MobaXterm (logs)"**: o anti-idle sobe junto.
4. Na primeira vez, clique com o botão direito no ícone > **Listar janelas do Moba** e confira se a janela do Moba está marcada com `[X]`. Se não estiver, ajuste `ClassesAlvo` no começo do `.ahk`.

**Limitação importante:** o Windows só deixa mandar teclas para a **aba ativa** de cada janela do Moba. Para manter várias sessões vivas, **destaque as abas importantes** (botão *Detach* ou arrastar a aba para fora): cada janela destacada recebe o anti-idle.

**Alternativa no equipamento** (se a política da empresa permitir):
- Cisco: `line vty 0 4` → `exec-timeout 0 0`. No NX-OS, só na sessão: `terminal session-timeout 0`.
- Huawei: `user-interface vty 0 4` → `idle-timeout 0 0`.
- Juniper, só na sessão atual, sem mexer na config: `set cli idle-timeout 0`.

---

## 5. Melhorias que valem a pena no MobaXterm

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

## 6. Problemas comuns

| Sintoma | Causa | Solução |
|---|---|---|
| `... não está assinado digitalmente` | Arquivos baixados vêm marcados "da internet" | `Get-ChildItem -Recurse \| Unblock-File` + `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. Se a empresa bloquear por GPO: `powershell -ExecutionPolicy Bypass -File .\Script.ps1` |
| `'}' de fechamento ausente` | Script copiado e colado do chat/navegador | Baixe a pasta inteira (zip ou GitHub). Os scripts dependem de `MobaTools.Common.ps1` e `config.psd1` |
| Alteração no ini "some" | O Moba estava aberto e regravou o ini ao fechar | Feche o Moba (inclusive o ícone perto do relógio) e rode de novo |
| Perfil "Custom: Redes" não aparece na lista | O Moba estava aberto, ou abriu outro ini (ex.: o do AppData) | Atualize os scripts e rode `Instalar-SyntaxRedes.ps1` de novo com o Moba fechado (ele move para os slots 3 e 2). A saída mostra o caminho do ini: tem que ser o que fica ao lado do `.exe` |
| Perfil completo não colore nada | O Moba pode ter limite de tamanho de regex | Use o perfil **"Custom: Redes compacto"** |
| Uma cor inteira para de funcionar (ex.: IPs brancos) | O Moba separa os padrões de cada cor por **vírgula**, então um `{1,4}` numa regex quebra o grupo todo | Não use vírgula nas regras. O `tools/gerar_syntax.py` recusa regra com vírgula |
| Texto piscando | Grupo 8 do Moba pisca | Já corrigido: o grupo 8 fica vazio. Rode `Instalar-SyntaxRedes.ps1` de novo |
| Moba abre sem as sessões/cores do OneDrive | O `.exe` é da versão **instalada**: ela ignora o ini ao lado dele e usa `%APPDATA%\MobaXterm\MobaXterm.ini` | Rode `Migrar-ParaPortable.ps1` de novo (ele grava `MobaIni` no `config.psd1`) e abra sempre pelo atalho **"MobaXterm (logs)"**, que passa `-i <ini do OneDrive>` |
| `MobaXterm-NOMEPC.ini` no OneDrive | Moba aberto nos dois PCs ao mesmo tempo | Compare, mantenha o certo como `MobaXterm.ini` e apague o outro |
| `AntiIdle ligado, mas o AutoHotkey v2 nao foi encontrado` | Falta o `AutoHotkey64.exe` | Dois cliques em `Instalar AntiIdle.cmd`, ou `AntiIdle = $false` no `config.psd1` para desligar |
| Ícone "MobaXterm (logs)" sumiu da Área de Trabalho | — | Dois cliques em `Criar Atalhos.cmd` |
| Atalho não abre nada / funciona num PC e no outro não | A Área de Trabalho sincroniza pelo OneDrive, e um atalho antigo guardava `C:\Users\<usuario do outro PC>\...` | Dois cliques em `Criar Atalhos.cmd` (os atalhos novos acham o OneDrive na hora, em cada PC). Se ainda falhar, o atalho mostra uma janela com o erro; detalhes em `%TEMP%\MobaTools\iniciar.log` e no `Diagnostico.cmd` |
| Anti-idle não envia | Janela do Moba não reconhecida | Ícone da bandeja > "Listar janelas do Moba" e ajuste `ClassesAlvo` no `.ahk` |

### Fontes
- [MobaXterm – documentação oficial (parâmetros de linha de comando, logs, shared sessions)](https://mobaxterm.mobatek.net/documentation.html)
- [Mobatek blog – MobaXterm configuration settings](https://blog.mobatek.net/post/mobaxterm-configuration-settings/)
- [Mobatek blog – How to configure the shared sessions](https://blog.mobatek.net/post/configure-shared-sessions/)
- [Mobatek blog – novidades da versão 10 (popup terminal, atalhos)](https://blog.mobatek.net/post/mobaxterm-new-release-10.0/)
- [SSH session disconnects in MobaXterm (keepalive)](https://community.oracle.com/customerconnect/discussion/636799/ssh-session-disconnects-after-a-few-minutes-of-inactivity-when-using-mobaxterm-client)
- [SecureCRT anti-idle / keepalive](https://www.itechguides.com/keep-securecrt-ssh-sessions-from-disconnecting-keepalives-timeouts-and-recovery/)
- [Syncing your SSH/RDP sessions with Dropbox and MobaXterm](https://grumpyneteng.com/syncing-your-sshrdp-sessions-with-dropbox-and-mobaxterm/)
