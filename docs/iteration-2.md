# Iterationsbericht 2: VPKG-Versionsbedingungen und Installer (15. bis 16.11.2026)

Auftrag: „Veyra OS – Full Operating System Development Mission“, Aufgaben 2 und 3 der
drei wichtigsten Aufgaben aus [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

## Was analysiert wurde

Wie das Abbild und die Live-ISO gebaut werden (`image/build-image.sh`, `build-iso.sh`,
`kernel/live/init.c`), was ein Installer im Basissystem vorfindet (util-linux, e2fsprogs,
Python, kein `mkfs.fat`), wie Partitionen ohne udev erreichbar sind, und welche
Prüfungen (VPKG, Konten) ein installiertes System bestehen muss.

## Welche Funktionen implementiert wurden

- **P1-3, VPKG 0.4:** Versionsbedingungen in `depends` (`name>=ver`, `=`, `<`, `<=`, `>`),
  beachtet beim Installieren, Entfernen und in `check` (aus Iteration 1, jetzt mit
  CI-Nachweis).
- **P3-2, Installer `veyra-install`** (neues Paket `veyra-installer`):
  - Logik in `veyra_install.py`, getrennt von der Kommandozeile `veyra-install`
    (`liste`, `pruefe ZIEL`, `installiere ZIEL`).
  - Erkennt vorhandene Systeme (Windows, Linux, Veyra, LUKS, BitLocker, Daten) und zeigt
    sie vor der Rückfrage an. Schreibt erst nach Eingabe des Gerätenamens.
  - Lehnt ab: Partition statt Datenträger, eingehängt oder Swap, von LVM/RAID benutzt,
    Startmedium, schreibgeschützt, nicht lesbar, 4K-Sektoren, zu klein, zweites
    `veyra-root` auf einem anderen Datenträger, unvollständiges Quellsystem.
  - GPT mit EFI-Partition (512 MiB, FAT32, Kernel als `BOOTX64.EFI`) und ext4-Root.
    Das FAT32 schreibt `veyra_fat.py` selbst, weil das Basissystem kein `mkfs.fat` hat.
  - Installiertes System: Variante `system`, root gesperrt bis zur Ersteinrichtung,
    su nur für `wheel`, eigene machine-id, Selbsttest per `vpkg remove` entfernt;
    Prüfung mit `vpkg check` und `veyra-kontencheck`. Die Root-Partition heißt erst nach
    allen Prüfungen `veyra-root`, ein Abbruch hinterlässt kein startbares Halbsystem.
- **VPKG 0.4.1:** fehlende Verzeichnisse unter `/run` (im laufenden System ein tmpfs)
  sind bei `check` kein Fehler mehr (gefunden durch den Installer-Test im CI).
- `veyra-konten` 0.2: `veyra-kontencheck` kennt die Variante `system` (Regeln wie `test`).
- `build-image.sh` legt den Kernel zusätzlich unter `/usr/lib/modules/VERSION/vmlinuz` ab;
  von dort schreibt ihn der Installer auf die EFI-Partition.

## Welche Dateien geändert wurden

Neu: `packages/base/veyra-installer/` (Rezept, `veyra-install`, `veyra_install.py`,
`veyra_fat.py`), `tests/installer/installer-test.sh`, `docs/installation.md`,
`docs/iteration-2.md`.
Geändert: `packages/base/vpkg/vpkg` und Rezept (0.4.1), `tests/vpkg/vpkg-test.sh`,
`packages/base/veyra-konten/veyra-kontencheck` und Rezept, `image/build-image.sh`,
`.github/workflows/toolchain.yml`, `ROADMAP.md`, `README.md`, `docs/SYSTEM_STATUS.md`,
`docs/DEVELOPMENT_PLAN.md`, `docs/vpkg.md`.

## Welche Tests ausgeführt wurden und mit welchem Ergebnis

Lokal (Ubuntu 24.04 wie der CI-Runner):

| Test | Ergebnis |
| --- | --- |
| `tests/installer/installer-test.sh` (als root, nur Abbild-Dateien als Ziel) | 15 von 15 bestanden |
| `tests/vpkg/vpkg-test.sh` | 28 von 28 als root, 29 von 29 ohne root |
| `tests/vpkg/run.sh` | 6 von 6 |
| `tests/konten/konten-test.sh`, `tests/image/variante-test.sh` | 17 von 17, 4 von 4 |
| shellcheck, `py_compile` | sauber |

CI:

| Lauf | Ergebnis |
| --- | --- |
| [43753648158](https://github.com/MagieGubi/Veyra-OS/actions/runs/43753648158) (VPKG 0.4) | alle Jobs grün |
| [43762694717](https://github.com/MagieGubi/Veyra-OS/actions/runs/43762694717) | rot: Installer lehnte die 4-GiB-Testplatte zu Recht ab (nötig 5830 MiB) |
| [43848376535](https://github.com/MagieGubi/Veyra-OS/actions/runs/43848376535) | rot: `vpkg check` meldete `/run/dbus` fälschlich als fehlend |
| [43856635308](https://github.com/MagieGubi/Veyra-OS/actions/runs/43856635308) | alle 12 Jobs grün |

Im grünen Lauf installiert der Installer das Entwicklungsabbild auf eine leere
8-GiB-Platte. QEMU startet sie (Login nach 6,6 s, `root=PARTLABEL=veyra-root`). Der
Selbsttest meldet: vpkg 0.4.1 mit 75 Paketen und 0 Fehlern, „Konten und Rechte: ok
(Variante system, 7 Pruefungen)“ und „Ersteinrichtung: wartet an Konsole 1 auf das
root-Passwort“. Netzwerk, Signaturen und Dienste sind ok, das System fährt sauber herunter.

Nicht ausgeführt: der Installer in der laufenden Live-ISO (im CI läuft derselbe Code auf
dem Runner) und die Eingabe des Gerätenamens von Hand. Nichts auf echter Hardware.

## Welche Probleme noch offen sind

- Nur ganze Datenträger: keine Installation neben Windows, keine manuelle Partitionierung.
- Basispakete werden mit ihrer VPKG-Datenbank kopiert statt einzeln über VPKG
  installiert. Dafür fehlt ein Paket für die Grunddateien (`/etc/passwd` usw.).
- Kein Kernel-Update auf der EFI-Partition, kein Bootloader, kein Secure Boot (P3-3).
- Das System ist mit Compiler und Entwicklungsdateien knapp 6 GiB groß.
- Kein PAM, kein sudo (P1-8).

## Was als Nächstes umgesetzt wird

Damit sind die drei wichtigsten Aufgaben aus Iteration 1 erledigt. Als Nächstes nach der
Phasenreihenfolge: Rettungsablauf mit der Live-ISO (P3-4, prüfbar in QEMU mit einer
absichtlich abgebrochenen Installation) und PAM/sudo bewerten (P1-8).
