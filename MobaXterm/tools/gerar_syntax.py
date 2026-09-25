#!/usr/bin/env python3
"""Gera Syntax-Redes.ini (perfis de syntax highlighting do MobaXterm para redes).

O MobaXterm tem 8 grupos de regex por perfil (Def1..Def8), cada um com uma cor FIXA
(Settings > Terminal > Customize): Def1 Sublinhado, Def2 Vermelho, Def3 Verde, Def4 Amarelo,
Def5 Azul, Def6 Magenta, Def7 Ciano, Def8 Piscando. Distribuicao usada (foco em Huawei VRP,
tambem cobre Cisco e Juniper):
  Def1 sublinhado  protocolos e blocos de config (bgp, ospf, interface...)
  Def2 vermelho    ruim
  Def3 verde       bom
  Def4 amarelo     atencao / warning e enderecos IP (IPv4/IPv6, linhas ip address)
  Def5 azul        prompt (nome do equipamento) + comandos
  Def6 magenta     MPLS / VPLS / L2VPN / L3VPN, RD/RT
  Def7 ciano       interfaces, MAC, AS
  Def8 piscando    vazio
No arquivo, o caractere U+00A8 marca inicio/fim de linha (o Moba usa isso no lugar de ^ e $).

Ideias adaptadas dos perfis de SecureCRT da comunidade:
  - feralpacket (feralpacket.org/?p=817 e github.com/feralpacket/securecrt-keyword-highlighting):
    categorias bom/ruim/atencao, contadores de erro so quando != 0, syslog por severidade,
    MPLS/LDP, RD/RT/VPNv4, prompt de config, reliability/txload
  - h-lopez/netOS-cli (MIT): u/u, u/D, A/D, formatos de MAC, termos de protocolo

Uso:  python3 tools/gerar_syntax.py      (grava ../Syntax-Redes.ini em Latin-1)
"""
from pathlib import Path

L = "\xa8"               # marcador de inicio/fim de linha do Moba
B = "[^A-Za-z0-9]"       # fronteira de palavra
K = "[^A-Za-z0-9_-]"     # fronteira que nao corta "ipv4-family", "NE40-BGP"
H = "[A-Za-z0-9_.-]+"    # hostname
LIMITE_COMPACTO = 690    # tamanho maximo das regras nativas do Moba


def alt(*partes):
    return "|".join(p for p in partes if p)


def palavras(lista, fronteira=B):
    return fronteira + "(" + lista + ")" + fronteira


# ------------------------------------------------------------------ Def1 MPLS / VPN
MPLS_CURTO = ("mpls l2vc|mpls ldp|mpls te|mpls lsp|mpls l2vpn|mpls|ldp|lsp|lsr-id|rsvp-te|mpls-te|te-tunnel|tunnel-policy|segment-routing|sr-mpls|srv6|"
              "label|imp-null|vpls|vsi|pw|pwe3|pw-template|l2vc|l2vpn|vpws|vll|evpn|bridge-domain|"
              "vpn-instance|vpn-target|route-distinguisher|vpnv4|vpnv6|l3vpn|vrf|vc-id")
MPLS_EXTRA = ("|rsvp|te|implicit-null|explicit-null|pop|swap|push|labels|in-label|out-label|ccc|svc|martini|"
              "kompella|evpl|bd|remote-peer|mpls-l2vc|control-word|mtu-negotiate|lsp-trigger|ldp-sync|"
              "export-extcommunity|import-extcommunity|ip-vpn|vpn|rd|rt|xconnect|l2transport|mpls-tp")
IPV4_BASE = r"([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.[0-9]+\.[0-9]+\.[0-9]+"
RD_RT = r"[1-9][0-9]{2,9}:[0-9]{1,10}(:" + IPV4_BASE + ")?|" + IPV4_BASE + r":[0-9]{1,5}"


def def1(completo):
    # "route-distinguisher 65001:100" / "vpn-target 65001:100 ...": o valor vai junto com a palavra
    valor = K + "(route-distinguisher|vpn-target) [0-9.:]+"
    return "(" + alt(valor, palavras(MPLS_CURTO + (MPLS_EXTRA if completo else ""), K), B + "(" + RD_RT + ")" + B) + ")"


# ------------------------------------------------------------------ Def2 vermelho (ruim)
PROMPT_CONFIG = (L + "(" + H + r"\(config[^)" + L + r"]*\)#|\[[~*][A-Za-z0-9_.:/-]+\]|\[edit[^\]" + L + r"]*\]|"
                 + H + "@" + H + "#)")
LINHA_NEGADA = L + "( *)?(no|undo|delete|deactivate) |" + L + "- [^" + L + "]*"
RUINS_CURTO = ("down|\\*down|admin-?down|administratively|err-disabled|disabled|shutdown|notconnect|"
               "error|failed|denied|refused|unreachable|timeout|idle|unselect|abnormal|offline|"
               "critical|alarm|half-duplex|u/d|a/d")
RUINS_EXTRA = ("|invalid|\\^down|failure|rejected|lost|blocking|suspended|unknown|fault|faulty|disconnected|"
               "notconnected|fail|not permitted|disallowed|not allowed|reject|problem|timed out|major|alert|"
               "emergency|inactive|half duplex|looped|loop-detected|duplicate|conflict|dying gasp|los|lof|"
               "expired|topology change|err-disable|absent|unregistered|not present|isolated|deny|wrong|cannot")
CONTADORES = (r"[^0-9.][1-9][0-9]* (input |output )?(errors|crc|drops|discards|runts|giants|collisions|overruns|"
              r"ignored|resets|throttles|underruns|frame|abort|no buffer)"
              r"|(crc|errors|drops|dropped|discards|discarded|total error|framing errors|runts|giants)[: ]+[1-9][0-9]*")
CONTADORES_CURTO = (r"[^0-9.][1-9][0-9]* (input |output )?(errors|crc|drops|discards)"
                    r"|(crc|errors|drops|discards|total error)[: ]+[1-9][0-9]*")
LIMITES = (r"[^0-9.](9[0-9]|100)(\.[0-9]+)?%|-(2[5-9]|[3-9][0-9])\.[0-9]+ ?dbm"
           r"|reliability ([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-4])/255|[rt]xload (2[3-4][0-9]|25[0-5])/255"
           r"|input queue: [0-9]+/[0-9]+/[1-9][0-9]*")
LIMITES_CURTO = r"[^0-9.](9[0-9]|100)(\.[0-9]+)?%|-(2[5-9]|[3-9][0-9])\.[0-9]+ ?dbm"
SYSLOG_RUIM = r"%%?[0-9]*[A-Za-z0-9_]+[-/][0-3][-/][A-Za-z0-9_]+"
FLAGS_RUINS = r"[0-9]\((b|d|e|s|i|dl|l)\)"


def def2(completo):
    ruins = RUINS_CURTO + (RUINS_EXTRA if completo else "")
    return "(" + alt(LINHA_NEGADA, PROMPT_CONFIG, " down ", palavras(ruins),
                     CONTADORES if completo else CONTADORES_CURTO,
                     LIMITES if completo else LIMITES_CURTO,
                     SYSLOG_RUIM, FLAGS_RUINS) + ")"


# ------------------------------------------------------------------ Def3 verde (bom)
BONS_CURTO = ("enabled|connected|up|\\*up|yes|ok|established|establ|full|forwarding|fwd|master|success|valid|"
              "best|selected|normal|registered|operational|u/u")
BONS_EXTRA = ("|primary|successful|passed|synced|in-sync|synchronized|reachable|full-duplex|full duplex|stable|"
              "permit|permitted|online|ready|good|root|designated")


def def3(completo):
    bons = BONS_CURTO + (BONS_EXTRA if completo else "")
    return "(" + alt(L + "\\+ [^" + L + "]*", palavras(bons), r"[0-9]\((p|su|ru)\)",
                     L + "( *)?(description|(host)?name(if)?|sysname|host-name) [^" + L + "]+") + ")"


# ------------------------------------------------------------------ enderecos IP (amarelo, Def4)
IPV4 = IPV4_BASE + r"(/[0-9]+)?"
IPV6 = r"([0-9a-f]{1,4}(:[0-9a-f]{1,4}){7}|[0-9a-f]{0,4}(:[0-9a-f]{1,4}){0,6}::([0-9a-f]{1,4}(:[0-9a-f]{1,4}){0,6})?)(/[0-9]+)?"


# ------------------------------------------------------------------ Def4 atencao / warning
ATENCAO_CURTO = ("active|connect|opensent|openconfirm|init|initialized|exstart|exchange|loading|2-way|attempt|"
                 "standby|backup|passive|mismatch|flapping|dampened|minor|warning")
ATENCAO_EXTRA = ("|learning|listening|rib-failure|flap|unsynchronized|pending|probe|degraded|"
                 "unstable|retransmission|retransmissions|timeouts|wait|waiting|"
                 "notification|unnumbered|discarding|alternate")
LIMITES_ATENCAO = r"[^0-9.](7[0-9]|8[0-9])(\.[0-9]+)?%|-(2[0-4])\.[0-9]+ ?dbm"
SYSLOG_ATENCAO = r"%%?[0-9]*[A-Za-z0-9_]+[-/]4[-/][A-Za-z0-9_]+"


def def4(completo):
    # amarelo tambem para os enderecos IP e as linhas "ip address ..." (pedido do usuario)
    ip_address = K + "(ip address|ipv6 address|ip binding|ip route-static)( [0-9a-f.:/]+)*"
    ips = B + "(" + alt(IPV4, IPV6 if completo else "") + ")" + B
    return "(" + alt(palavras(ATENCAO_CURTO + (ATENCAO_EXTRA if completo else ""), K),
                     LIMITES_ATENCAO, SYSLOG_ATENCAO, ip_address, ips) + ")"


# ------------------------------------------------------------------ Def5 protocolos / blocos de config
BLOCOS_CURTO = ("interface|bgp|ospf|ospfv3|isis|rip|static|direct|ibgp|ebgp|o_ase|o_nssa|isis-l1|isis-l2|"
                "route-policy|ip-prefix|acl|qos|traffic-policy|peer|group|ipv4-family|ipv6-family|"
                "pppoe|bas|radius|aaa|domain|ip pool|dhcp|nat|vrrp|bfd|lacp|stp|lldp|nqa|snmp-agent|"
                "info-center|user-interface|local-user")
BLOCOS_EXTRA = ("|router|neighbor|address-family|family|unit|protocols|policy-options|policy-statement|"
                "term|routing-options|routing-instances|firewall|filter|snmp-server|logging|line vty|ntp|"
                "ntp-service|spanning-tree|hsrp|route-map|policy-map|class-map|prefix-list|access-list|"
                "community-filter|as-path-filter|traffic classifier|traffic behavior|eigrp|pim|igmp|"
                "multicast|switchport|port link-type|port trunk|access-user|web-auth|dot1x|mac-address")


def def5(completo):
    return palavras(BLOCOS_CURTO + (BLOCOS_EXTRA if completo else ""), K)


# ------------------------------------------------------------------ Def6 enderecos / interfaces
MAC = r"([0-9a-f]{2}[:-]){5}[0-9a-f]{2}|[0-9a-f]{4}[.-][0-9a-f]{4}[.-][0-9a-f]{4}|[0-9a-f]{6}-[0-9a-f]{6}"
IFACE_CURTO = ("gigabitethernet|ethernet|eth-trunk|loopback|tunnel|vbdif|nve|meth|null|virtual-ethernet|"
               "global-ve|virtual-template|pos|serial|port-channel|gi|te|hu|po|ge|xge|10ge|25ge|40ge|"
               "50ge|100ge|200ge|400ge|lo|xe|et|ae")
IFACE_EXTRA = ("|tengigabitethernet|twentyfivegige|fortygigabitethernet|hundredgige|fastethernet|bundle-ether|"
               "tw|fo|fa|eth|be|irb|em|fxp|me|gr|lt|mgmt|ve")


def def6(completo):
    nomes = IFACE_CURTO + (IFACE_EXTRA if completo else "")
    iface = "(" + nomes + r")-?[0-9]+(/[0-9]+)*(\.[0-9]+)?(:[0-9]+)?|irb\.[0-9]+|vlan(if)?[ -]?[0-9]+"
    return B + "(" + alt(MAC, iface, "as ?[0-9]+") + ")" + B


# ------------------------------------------------------------------ Def7 comandos e prompts
CMDS = ("show|display|dis|sh|ping|traceroute|tracert|trace|telnet|ssh|stelnet|configure|conf t|system-view|sys|"
        "commit|rollback|compare|quit|return|exit|end|save|write|wr|copy|run|request|monitor|terminal|debug|"
        "debugging|clear|reset|set|activate|edit|top")
CMDS_EXTRA = ("|commit check|route|access-(list|group)|"
              "port-forward|mtu|speed|duplex|autoneg|negotiation auto|rate-limit|encapsulation|media-type")
# prompts normais (fora do modo config): <HUAWEI>, user@mx>, R1#, R1>
PROMPT = L + "(<[A-Za-z0-9_.:/-]+>|" + H + "@" + H + "[>%]|" + H + "[#>])"


def def7(completo):
    # prompts vao junto com os comandos (azul); o grupo 8 do Moba PISCA
    return "(" + palavras(CMDS + (CMDS_EXTRA if completo else ""), K) + "|" + PROMPT + "(" + CMDS + ")?)"


def perfil(nome, completo):
    # def1 = MPLS, def5 = protocolos, def6 = enderecos, def7 = comandos/prompts (nomes das funcoes)
    defs = {1: def5(completo),   # sublinhado: protocolos
            2: def2(completo),   # vermelho: ruim
            3: def3(completo),   # verde: bom
            4: def4(completo),   # amarelo: atencao
            5: def7(completo),   # azul: prompt + comandos
            6: def1(completo),   # magenta: MPLS / VPN
            7: def6(completo),   # ciano: enderecos / interfaces
            8: ""}               # piscando: nao usar
    if not completo:
        grandes = {i: len(v) for i, v in defs.items() if len(v) > LIMITE_COMPACTO}
        assert not grandes, f"perfil compacto passou de {LIMITE_COMPACTO} caracteres: {grandes}"
    return ["Name=" + nome, "UseRegex=1"] + [f"Def{i}={defs[i]}" for i in range(1, 9)] + ["CaseSensitive=0"]


cabecalho = [
    "; Syntax highlighting de redes para o MobaXterm (Huawei VRP, Cisco IOS/XE/XR/NX-OS, Juniper Junos)",
    "; Gerado por tools/gerar_syntax.py - edite o gerador, nao este arquivo.",
    "; Grupos: 1 sublinhado=protocolos | 2 vermelho=ruim | 3 verde=bom | 4 amarelo=atencao+IPs | 5 azul=prompt+comandos | 6 magenta=MPLS/VPN | 7 ciano=interfaces/MAC",
    "; Instale com: .\\Instalar-SyntaxRedes.ps1   (com o MobaXterm FECHADO)",
    "; Dois perfis: o completo e um compacto (regras <= 690 caracteres, como as nativas do Moba).",
    "; Arquivo em Latin-1: o caractere '" + L + "' marca inicio/fim de linha nas regex do Moba.",
]
secoes = (["[CustomSyntaxRedes]"] + perfil("Custom: Redes (Cisco/Huawei/Juniper)", True) + [""] +
          ["[CustomSyntaxRedesCompacto]"] + perfil("Custom: Redes compacto", False))
destino = Path(__file__).resolve().parent.parent / "Syntax-Redes.ini"
destino.write_bytes(("\r\n".join(cabecalho + secoes) + "\r\n").encode("latin-1"))
print(f"gravado {destino}")
