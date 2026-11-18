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
und Kernel-Log nur für root, `ptrace` nur auf eigene Kindprozesse, BPF nur für root mit
gehärtetem JIT, kein `kexec`, keine Speicherabbilder von setuid-Programmen, Schutz bei
Links, FIFOs und Dateien in fremden Verzeichnissen, keine ICMP-Umleitungen, kein
Source-Routing, SYN-Cookies.

Nachweis: Der Selbsttest liest jeden Wert der Datei im laufenden System zurück, prüft, dass
Yama aktiv ist und nftables im Kernel steckt („Kernel-Härtung: ok“).

## Bewusst noch nicht

- Modulsignaturen und Lockdown (Lockdown erzwingt Modulsignaturen): würden den bit-identischen Kernel-Build brechen (Entscheidung in
  PLAN_0.6.md).
- Firewall-Regeln: der Kernel kann nftables, das Programm `nft` und die Regeln folgen.
