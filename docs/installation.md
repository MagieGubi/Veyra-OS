# Veyra installieren (veyra-install)

Stand: 16.11.2026, Installer 0.3. **Bisher nur auf virtuellen Platten geprüft**
(Tests in `tests/installer/installer-test.sh`; im CI Installation auf eine leere
8-GiB-Platte und Boot mit Selbsttest in QEMU, zuerst grün in Lauf [43856635308](https://github.com/MagieGubi/Veyra-OS/actions/runs/43856635308)).
Auf einem echten Datenträger ist der Installer noch nie gelaufen.

## Was der Installer macht

Er kopiert das laufende Live-System (das unveränderte SquashFS der Live-ISO unter
`/run/veyra-live/sfs`) auf einen ganzen Datenträger und richtet es als installiertes
System ein:

| Partition | Größe | Inhalt |
| --- | --- | --- |
| 1 `veyra-efi` | 512 MiB | EFI-Systempartition (FAT32): systemd-boot, Kernel unter `/veyra/VERSION/linux`, Booteintrag |
| 2 `veyra-root` | Rest | Root-Dateisystem (ext4) |

Ab 0.6 startet das installierte System über **systemd-boot** (`--bootweg systemd-boot`,
Standard): `\EFI\BOOT\BOOTX64.EFI` ist systemd-boot, der Eintrag
`loader/entries/veyra-VERSION+3.conf` findet Root über `root=PARTUUID=...` (also genau
diese Platte, auch wenn ein Veyra-USB-Stick steckt) und zählt Startversuche. Erst ein
vollständiger Start ohne fehlgeschlagene Units macht den Eintrag dauerhaft
(`systemd-bless-boot` benennt ihn in `veyra-VERSION.conf` um); scheitert ein Eintrag
dreimal, wählt systemd-boot einen anderen. Menü 3 Sekunden, Editor aus.

`--bootweg direkt` installiert wie in 0.5 ohne Bootloader: der Kernel selbst ist
`BOOTX64.EFI` und findet Root über `root=PARTLABEL=veyra-root` (eingebaute Kommandozeile).

Im installierten System ist root gesperrt. Der Installer fragt an der Konsole, ob
root-Passwort und Benutzer gleich festgelegt werden sollen (dieselbe Ersteinrichtung wie
beim ersten Start, nur im neuen System). Sonst fragt die Ersteinrichtung beim ersten Start
an Konsole 1 nach dem root-Passwort und legt auf Wunsch einen Benutzer in der Gruppe `wheel`
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
`--mit-selbsttest` (Selbsttest behalten, für Tests in der VM), `--konten` (Konten
jetzt festlegen, ohne Rückfrage; liest auch zeilenweise von stdin), `--konten-spaeter`
(Ersteinrichtung beim ersten Start), `--bestaetigt ZIEL`
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

Scheitert das Schreiben der Partitionstabelle selbst, stellt der Installer die alte
wieder her (er sichert vorher das erste und letzte MiB des Ziels); auf dem Ziel ist dann
nichts verändert. Bricht die Installation später ab, heißt die
Root-Partition noch `veyra-unfertig`; erst ganz am Ende wird sie in `veyra-root`
umbenannt. Ein halb installiertes System startet also nicht versehentlich.

## Im installierten System

- Die EFI-Partition steht in der fstab unter `/efi` (beim ersten Zugriff eingehängt,
  nach 60 s wieder ausgehängt, nur root).
- Beim Start prüft `veyra-rootpruefung.service`, ob mehr als eine Partition `veyra-root`
  heißt (zum Beispiel installierte Platte und Veyra-USB-Stick). Dann steht eine Warnung im
  Journal, auf der Konsole und über der Anmeldeaufforderung, mit dem tatsächlich
  gestarteten Gerät. Mit systemd-boot (ab 0.6) startet jede Platte ihr eigenes Root
  (`PARTUUID`); nur mit `--bootweg direkt` ist offen, welches startet.

## Aufbau

- `packages/base/veyra-installer/veyra_install.py`: Logik (Untersuchen, Plan,
  Partitionieren, Kopieren, Einrichten, Prüfen), ohne Ein- und Ausgabe.
- `packages/base/veyra-installer/veyra_fat.py`: schreibt das FAT32 der
  EFI-Systempartition. Das Basissystem hat kein `mkfs.fat`; das Modul legt das
  Dateisystem mit den nötigen Dateien direkt an (lange Namen ab 0.6, geprüft mit
  `fsck.fat` und mtools).
- `packages/base/veyra-installer/veyra-install`: Kommandozeile mit Rückfrage.
- `packages/base/veyra-installer/veyra-rootpruefung`: Warnung bei zwei `veyra-root`.
- `image/install-test.py`: startet die installierte Platte in QEMU, tippt die
  Ersteinrichtung an Konsole 1 ein, meldet sich an, prüft `su` und startet neu (CI).

Partitionen spricht der Installer über ihren Versatz an (Loop-Gerät mit `--offset`),
nicht über `/dev/sdX1`; das funktioniert gleich für echte Datenträger und Abbild-Dateien.

## Grenzen (offen)

- Nur ganze Datenträger, keine Installation neben Windows (kein Verkleinern vorhandener
  Partitionen, keine manuelle Partitionierung).
- Kernel-Updates auf der EFI-Partition gibt es noch nicht (kommt mit `veyra-kernel-update`
  in 0.6); kein Secure Boot.
- Die Basispakete werden als fertiges System kopiert, mit ihrer VPKG-Datenbank, nicht
  einzeln über VPKG installiert. Dafür fehlt noch ein Paket für die Grunddateien
  (`/etc/passwd` und Co.).
- Nur ext4, keine Verschlüsselung.
- Die Rückfrage an der Live-Konsole wurde nur per Test geprüft, nicht von Hand in der VM.
