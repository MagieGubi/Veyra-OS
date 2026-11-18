# Sicherheit in Veyra OS

Stand: 18.11.2026 (0.6 in Arbeit). Was hier steht, ist umgesetzt; der Nachweis steht
jeweils dabei. Offene Punkte: [PLAN_0.6.md](PLAN_0.6.md).

## Konten und Rechte (seit 0.4/0.5)

root ist bis zur Ersteinrichtung gesperrt, nur `wheel` darf `su`, kein PAM, kein `sudo`.
Nachweis: `image/install-test.py` im CI (root ohne Passwort abgewiesen, `/etc/shadow` für
Benutzer nicht lesbar, `su` nur mit Passwort). Anmelde-Shells halten das Herunterfahren
nicht auf (getty-Dienste: SIGHUP, höchstens 5 s).

## Kernel-Härtung (0.6, Kernel 6.18.56-veyra3)

Fragment `kernel/config/veyra-50-security.config`: Stack-Schutz, `FORTIFY_SOURCE`,
geprüfte Kopien zwischen Kernel und Programmen, genullter neuer Speicher, KASLR,
schreibgeschützter Kernel-Code, gehärtete Slab-Freilisten, Listenprüfung, `/dev/mem` nur
für Gerätespeicher, kein `TIOCSTI`, Yama. Lockdown fehlt, weil es Modulsignaturen erzwingt
(siehe unten). `build-kernel.sh` bricht ab, wenn Kconfig eine Option verwirft.

Paket `veyra-sicherheit`, Datei `/usr/lib/sysctl.d/50-veyra-sicherheit.conf`: Kernel-Adressen
und Kernel-Log nur für root, `ptrace` nur auf eigene Kindprozesse, BPF nur für root (kein BPF-JIT im
Kernel), kein `kexec`, keine Speicherabbilder von setuid-Programmen, Schutz bei
Links, FIFOs und Dateien in fremden Verzeichnissen, keine ICMP-Umleitungen, kein
Source-Routing, SYN-Cookies.

Nachweis: Der Selbsttest liest jeden Wert der Datei im laufenden System zurück, prüft, dass
Yama aktiv ist und nftables im Kernel steckt („Kernel-Härtung: ok“).

## Firewall (0.6)

Pakete `libmnl`, `libnftnl`, `nftables` (Stufe 4b, Teil 4; Quellen per Signatur des
netfilter-Projekts geprüft, der Schlüssel muss von netfilter.org und vom Schlüsselserver
übereinstimmen) und `veyra-firewall`. Der Dienst `veyra-firewall.service` lädt
`/etc/nftables.conf` vor dem Netz: eingehend verwerfen außer Loopback, Antworten auf eigene
Verbindungen, nötiges ICMP und ICMPv6 (Nachbarn, Router, Fehlermeldungen), begrenztes Ping
und DHCP-Antworten; Weiterleiten verwerfen; ausgehend frei. Kein Port ist offen.

Nachweis: `tests/firewall/firewall-test.sh` (`nft -c`, Grundsätze), Selbsttest
„Firewall: ok“ und weiterhin „Netzwerk: ok“ (DHCP, DNS) und „Offene Ports: ok“ im
gebooteten Abbild.

## Bewusst noch nicht

- Modulsignaturen und Lockdown (Lockdown erzwingt Modulsignaturen): würden den bit-identischen Kernel-Build brechen (Entscheidung in
  PLAN_0.6.md).

