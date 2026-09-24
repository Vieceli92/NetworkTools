#!/usr/bin/env python3
"""Gera Syntax-Redes.ini (perfis de syntax highlighting do MobaXterm para redes).

O MobaXterm tem 8 grupos de regex por perfil (Def1..Def8), cada um com uma cor fixa.
Seguindo o esquema dos perfis nativos do Moba:
  Def1 URL | Def2 ruim (vermelho) | Def3 bom (verde) | Def4 enderecos/interfaces
  Def5 comentarios | Def6 blocos/protocolos | Def7 comandos | Def8 prompts
No arquivo, o caractere U+00A8 marca inicio/fim de linha (o Moba usa isso no lugar de ^ e $).

Ideias adaptadas dos perfis de SecureCRT da comunidade:
  - feralpacket/securecrt-keyword-highlighting (contadores de erro so quando != 0,
    prompt de config destacado, logging por severidade, reliability/txload, RT/RD)
  - h-lopez/netOS-cli (MIT) (u/u, u/D, A/D, formatos de MAC, termos de protocolo)

Uso:  python3 tools/gerar_syntax.py      (grava ../Syntax-Redes.ini em Latin-1)
"""
from pathlib import Path

L = "\xa8"               # marcador de inicio/fim de linha do Moba
B = "[^A-Za-z0-9]"       # fronteira de palavra
K = "[^A-Za-z0-9_-]"     # fronteira que nao corta "ipv4-family", "NE40-BGP"
H = "[A-Za-z0-9_.-]+"    # hostname

def alt(*partes):
    return "|".join(p for p in partes if p)

# ------------------------------------------------------------------ Def2 vermelho
PROMPT_CONFIG = (L + "(" + H + r"\(config[^)" + L + r"]*\)#|\[[~*][A-Za-z0-9_.:/-]+\]|\[edit[^\]" + L + r"]*\]|"
                 + H + "@" + H + "#)")
LINHA_NEGADA = L + "( *)?(no|undo|delete|deactivate) |" + L + "- [^" + L + "]*"
RUINS_CURTO = ("down|\\*down|admin-?down|administratively|err-disabled|disabled|shutdown|notconnect|"
               "error|failed|denied|refused|unreachable|timeout|idle|connect|opensent|openconfirm|exstart|"
               "critical|alarm|half-duplex|u/d|a/d")
RUINS_EXTRA = ("|invalid|\\^down|failure|rejected|exchange|loading|init|flapping|lost|mismatch|blocking|suspended|unknown|fault|faulty|disconnected|notconnected|fail|not permitted|disallowed|not allowed|reject|"
               "problem|timed out|flap|major|alert|emergency|inactive|half duplex|looped|loop-detected|duplicate|"
               "conflict|dying gasp|los|lof|expired|topology change|err-disable")
CONTADORES = (r"[^0-9.][1-9][0-9]* (input |output )?(errors|crc|drops|discards|runts|giants|collisions|overruns|"
              r"ignored|resets|throttles|underruns|frame|abort|no buffer)"
              r"|(crc|errors|drops|dropped|discards|discarded|total error|framing errors|runts|giants)[: ]+[1-9][0-9]*")
CONTADORES_CURTO = (r"[^0-9.][1-9][0-9]* (input |output )?(errors|crc|drops|discards|runts|giants|overruns|ignored)"
                    r"|(crc|errors|drops|discards|total error)[: ]+[1-9][0-9]*")
LIMITES = (r"[^0-9.](9[0-9]|100)(\.[0-9]+)?%|-(2[5-9]|[3-9][0-9])\.[0-9]+ ?dbm"
           r"|reliability ([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-4])/255|[rt]xload (2[3-4][0-9]|25[0-5])/255"
           r"|input queue: [0-9]+/[0-9]+/[1-9][0-9]*")
LIMITES_CURTO = r"[^0-9.](9[0-9]|100)(\.[0-9]+)?%|-(2[5-9]|[3-9][0-9])\.[0-9]+ ?dbm"
SYSLOG = r"%%?[0-9]*[A-Za-z0-9_]+[-/][0-3][-/][A-Za-z0-9_]+"
FLAGS_RUINS = r"[0-9]\((b|d|e|s|i)\)"

def def2(completo):
    ruins = RUINS_CURTO + (RUINS_EXTRA if completo else "")
    return "(" + alt(LINHA_NEGADA, PROMPT_CONFIG, " down ", B + "(" + ruins + ")" + B,
                     CONTADORES if completo else CONTADORES_CURTO,
                     LIMITES if completo else LIMITES_CURTO,
                     SYSLOG, FLAGS_RUINS) + ")"

# ------------------------------------------------------------------ Def3 verde
BONS_CURTO = "enabled|connected|up|\\*up|yes|ok|established|establ|full|forwarding|fwd|master|success|valid|best|u/u"
BONS_EXTRA = "|primary|successful|passed|synced|in-sync|reachable|selected|full-duplex|full duplex|stable|permit|permitted"

def def3(completo):
    bons = BONS_CURTO + (BONS_EXTRA if completo else "")
    return "(" + alt(L + "\\+ [^" + L + "]*", B + "(" + bons + ")" + B, r"[0-9]\((p|su|ru)\)",
                     L + "( *)?(description|(host)?name(if)?|sysname|host-name) [^" + L + "]+") + ")"

# ------------------------------------------------------------------ Def4 enderecos / interfaces
IPV4 = r"([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+|:[0-9]+)?"
IPV6 = r"([0-9a-f]{1,4}(:[0-9a-f]{1,4}){7}|[0-9a-f]{0,4}(:[0-9a-f]{1,4}){0,6}::([0-9a-f]{1,4}(:[0-9a-f]{1,4}){0,6})?)(/[0-9]+)?"
MAC = r"([0-9a-f]{2}[:-]){5}[0-9a-f]{2}|[0-9a-f]{4}[.-][0-9a-f]{4}[.-][0-9a-f]{4}|[0-9a-f]{6}-[0-9a-f]{6}"
IFACE_NOMES = ("gigabitethernet|tengigabitethernet|twentyfivegige|fortygigabitethernet|hundredgige|fastethernet|"
               "ethernet|port-channel|bundle-ether|eth-trunk|loopback|tunnel|vbdif|nve|meth|null|virtual-ethernet|"
               "gi|te|tw|fo|hu|fa|eth|po|be|ge|xge|10ge|25ge|40ge|50ge|100ge|200ge|400ge|lo|xe|et|ae|irb|em|fxp|me|gr|lt|mgmt")
IFACE = "(" + IFACE_NOMES + r")-?[0-9]+(/[0-9]+)*(\.[0-9]+)?|irb\.[0-9]+|vlan(if)?[ -]?[0-9]+"
RT_RD = r"[0-9]{3,10}:[0-9]{1,10}|as ?[0-9]+"

def def4(completo):
    return B + "(" + alt(MAC, "localhost", IPV4, IPV6 if completo else "", IFACE, RT_RD) + ")" + B

# ------------------------------------------------------------------ Def5..Def8
DEF5 = "(" + L + "( *)?[!#][^" + L + "]*)+"
BLOCOS = ("interface|router|bgp|ospf|ospfv3|isis|mpls|ldp|rsvp|segment-routing|srv6|vpn-instance|vrf|l2vc|l2vpn|"
          "vsi|vpls|evpn|bridge-domain|route-policy|route-map|policy-map|class-map|traffic-policy|ip-prefix|"
          "prefix-list|acl|access-list|qos|peer|group|neighbor|ipv4-family|ipv6-family|address-family|family|unit|"
          "protocols|policy-options|policy-statement|term|routing-options|routing-instances|firewall|filter|"
          "snmp-agent|snmp-server|logging|info-center|aaa|local-user|user-interface|line vty|ntp|lacp|stp|"
          "spanning-tree|lldp|bfd|vrrp|hsrp|nqa|pppoe|bas|radius|domain|ip pool|dhcp|nat")
BLOCOS_EXTRA = ("|rip|eigrp|class|traffic classifier|traffic behavior|community-filter|as-path-filter|from|then|"
                "chassis|system|security|services|ntp-service|switchport|port link-type|port trunk|security-level|"
                "failover|static|global|service(-policy)?|xconnect|pim|igmp|multicast")
CMDS = ("show|display|dis|sh|ping|traceroute|tracert|trace|telnet|ssh|stelnet|configure|conf t|system-view|sys|"
        "commit|rollback|compare|quit|return|exit|end|save|write|wr|copy|run|request|monitor|terminal|debug|"
        "debugging|clear|reset|set|activate|edit|top")
CMDS_EXTRA = ("|commit check|ip( address)?|ipv6 address|route|ip route-static|route-static|access-(list|group)|"
              "port-forward|mtu|speed|duplex|autoneg|negotiation auto|rate-limit|encapsulation|media-type")
DEF8 = L + "(<[A-Za-z0-9_.:/-]+>|" + H + "@" + H + "[>%]|" + H + "[#>])"
URL = r"[^A-Za-z_&-](http(s)?://[A-Za-z0-9_.&?=%~#{}()@+-]+:?[A-Za-z0-9_./&?=%~#{}()@+-]+)[^A-Za-z0-9_-]"

def perfil(nome, completo):
    defs = {
        1: URL,
        2: def2(completo),
        3: def3(completo),
        4: def4(completo),
        5: DEF5,
        6: K + "(" + BLOCOS + (BLOCOS_EXTRA if completo else "") + ")" + K,
        7: K + "(" + CMDS + (CMDS_EXTRA if completo else "") + ")" + K,
        8: DEF8,
    }
    if not completo:
        grandes = {i: len(v) for i, v in defs.items() if len(v) > 690}
        assert not grandes, f"perfil compacto passou de 690 caracteres: {grandes}"
    return ["Name=" + nome, "UseRegex=1"] + [f"Def{i}={defs[i]}" for i in range(1, 9)] + ["CaseSensitive=0"]

cabecalho = [
    "; Syntax highlighting de redes para o MobaXterm (Cisco IOS/XE/XR/NX-OS, Huawei VRP, Juniper Junos)",
    "; Gerado por tools/gerar_syntax.py - edite o gerador, nao este arquivo.",
    "; Instale com: .\\Instalar-SyntaxRedes.ps1   (com o MobaXterm FECHADO)",
    "; Dois perfis: o completo e um compacto (regras <= 690 caracteres, como as nativas do Moba).",
    "; Se o completo nao colorir no seu Moba, use o compacto.",
    "; Arquivo em Latin-1: o caractere '" + L + "' marca inicio/fim de linha nas regex do Moba.",
]
secoes = (["[CustomSyntaxRedes]"] + perfil("Custom: Redes (Cisco/Huawei/Juniper)", True) + [""] +
          ["[CustomSyntaxRedesCompacto]"] + perfil("Custom: Redes compacto", False))
destino = Path(__file__).resolve().parent.parent / "Syntax-Redes.ini"
destino.write_bytes(("\r\n".join(cabecalho + secoes) + "\r\n").encode("latin-1"))
print(f"gravado {destino}")
