# Veyra installieren (veyra-install)

Stand: 15.11.2026, Installer 0.1. **Bisher nur auf virtuellen Platten geprüft**
(Tests in `tests/installer/installer-test.sh`, Installation und Boot in QEMU im CI).
Auf einem echten Datenträger ist der Installer noch nie gelaufen.

## Was der Installer macht

Er kopiert das laufende Live-System (das unveränderte SquashFS der Live-ISO unter
`/run/veyra-live/sfs`) auf einen ganzen Datenträger und richtet es als installiertes
System ein:

| Partition | Größe | Inhalt |
| --- | --- | --- |
| 1 `veyra-efi` | 512 MiB | EFI-Systempartition (FAT32), Veyra-Kernel als `\EFI\BOOT\BOOTX64.EFI` |
| 2 `veyra-root` | Rest | Root-Dateisystem (ext4) |

Wie das Abbild startet das installierte System ohne Bootloader: die UEFI-Firmware startet
den Kernel direkt, der Kernel findet sein Root über `root=PARTLABEL=veyra-root`.

Im installierten System ist root gesperrt. Beim ersten Start fragt die Ersteinrichtung an
Konsole 1 nach dem root-Passwort und legt auf Wunsch einen Benutzer in der Gruppe `wheel`
an (nur `wheel` darf `su`). Der Selbsttest wird entfernt (`vpkg remove veyra-selftest`).
Zum Schluss prüft der Installer das Ergebnis mit `vpkg check` und `veyra-kontencheck`.

## Bedienung (in der Live-ISO, als root)

```
veyra-install liste                    # Datenträger, Partitionen, erkannte Systeme
veyra-install pruefe /dev/sdX          # was darauf liegt und was danach darauf liegt
veyra-install installiere /dev/sdX     # installieren
```

**Alle Daten auf dem Ziel gehen verloren.** Der Installer schreibt erst, nachdem der
Gerätename (z. B. `/dev/sdX`) eingetippt wurde. Er zeigt vorher, was auf dem Ziel liegt
(Windows, Linux, Veyra, verschlüsselte Partitionen, Daten).

Optionen für `installiere`: `--hostname NAME`, `--quelle VERZ` (anderes Quellsystem),
`--mit-selbsttest` (Selbsttest behalten, für Tests in der VM), `--bestaetigt ZIEL`
(Bestätigung ohne Rückfrage, nur für automatische Tests auf virtuellen Platten; muss
genau dem Ziel entsprechen).

## Wann der Installer ablehnt

- Das Ziel ist eine Partition statt eines ganzen Datenträgers.
- Das Ziel oder eine seiner Partitionen ist eingehängt oder als Swap aktiv.
- Das Ziel wird von LVM, RAID oder einer Verschlüsselung benutzt.
- Das Ziel trägt das Startmedium (den USB-Stick der Live-ISO).
- Das Ziel ist schreibgeschützt, nicht lesbar (vorhandene Daten nicht prüfbar) oder hat
  4K-Sektoren.
- Das Ziel ist zu klein (Quellsystem plus 15 %, 1 GiB frei, 512 MiB EFI; beim heutigen
  Basissystem mit Compiler und Entwicklungsdateien knapp 6 GiB).
- Auf einem anderen Datenträger gibt es schon eine Partition `veyra-root` (der Kernel
  könnte sonst das falsche System starten).
- Das Quellsystem ist unvollständig (kein systemd, VPKG, Ersteinrichtung oder Kernel).

Bricht die Installation nach dem Schreiben der Partitionstabelle ab, heißt die
Root-Partition noch `veyra-unfertig`; erst ganz am Ende wird sie in `veyra-root`
umbenannt. Ein halb installiertes System startet also nicht versehentlich.

## Aufbau

- `packages/base/veyra-installer/veyra_install.py`: Logik (Untersuchen, Plan,
  Partitionieren, Kopieren, Einrichten, Prüfen), ohne Ein- und Ausgabe.
- `packages/base/veyra-installer/veyra_fat.py`: schreibt das FAT32 der
  EFI-Systempartition. Das Basissystem hat kein `mkfs.fat`; das Modul legt das
  Dateisystem mit den nötigen Dateien direkt an (nur kurze Namen, geprüft mit `fsck.fat`).
- `packages/base/veyra-installer/veyra-install`: Kommandozeile mit Rückfrage.

Partitionen spricht der Installer über ihren Versatz an (Loop-Gerät mit `--offset`),
nicht über `/dev/sdX1`; das funktioniert gleich für echte Datenträger und Abbild-Dateien.

## Grenzen (offen)

- Nur ganze Datenträger, keine Installation neben Windows (kein Verkleinern vorhandener
  Partitionen, keine manuelle Partitionierung).
- Kernel-Updates auf der EFI-Partition gibt es noch nicht (P3-3, P3-4); ebenso keinen
  Bootloader und kein Secure Boot.
- Die Basispakete werden als fertiges System kopiert, mit ihrer VPKG-Datenbank, nicht
  einzeln über VPKG installiert. Dafür fehlt noch ein Paket für die Grunddateien
  (`/etc/passwd` und Co.).
- Nur ext4, keine Verschlüsselung.
- Die Rückfrage an der Live-Konsole wurde nur per Test geprüft, nicht von Hand in der VM.
