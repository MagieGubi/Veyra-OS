# Messwerte

Erste Messwerte von Veyra Core 0.1. Gemessen im CI in einer virtuellen Maschine
(QEMU mit KVM, 2 CPU-Kerne, 2 GiB RAM, OVMF-Firmware, virtio-Platte). Das sind keine
Werte für echte Hardware; die kommen in Phase 6 auf Adrians Testrechner.

Quelle: [CI-Lauf 38388817792](https://github.com/MagieGubi/Veyra-OS/actions/runs/38388817792),
13.10.2026. Ausgabe von `image/boot-test.sh` und dem Selbsttest im Abbild.

| Messgröße | Wert |
| --- | --- |
| QEMU-Start bis Login-Aufforderung | 6,4 s |
| davon Firmware (bis zur ersten Kernel-Ausgabe) | 2,3 s |
| Kernel (systemd-analyze) | 1,097 s |
| Userspace bis Ziel erreicht (systemd-analyze) | 1,290 s |
| Belegter Arbeitsspeicher nach dem Start | 109 MiB von 1967 MiB |
| Prozesse | 97, davon 75 Kernel-Threads |
| Laufende Dienste | 10 |
| Belegter Platz auf dem Root-Dateisystem | 3811 MiB |

Langsamste Startschritte (systemd-analyze blame): Root-Gerät `dev-vda2.device` 491 ms,
`systemd-hwdb-update` 256 ms, `systemd-random-seed` 194 ms, `systemd-resolved` 147 ms.

Anmerkungen:

- Die frühere Angabe „8,1 s bis zum Login“ war ohne Aufteilung gemessen. In den Läufen,
  in denen der Selbsttest während des Starts lief, kam die Anmeldung erst nach etwa 12 s,
  weil `vpkg check` alle Dateien prüfte. Der Selbsttest startet deshalb jetzt per Timer
  20 s nach dem Booten.
- Das Root-Dateisystem enthält noch die komplette Bau-Umgebung (GCC, Perl, Python,
  Header). Ein schlankeres Laufzeit-Abbild ist ein offener Punkt.
- `systemd-hwdb-update` läuft bei jedem Start des frischen Abbilds; auf einem installierten
  System nur nach Aktualisierungen.
