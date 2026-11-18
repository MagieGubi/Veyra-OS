# Recovery: ein installiertes Veyra retten

Startet ein installiertes Veyra nicht mehr oder meldet `vpkg check` Fehler, hilft die
Live-ISO. Sie enthält `veyra-recovery` (Paket `veyra-recovery`, Veyra 0.6).

## Ablauf

1. Von der Live-ISO starten (USB-Stick oder CD, UEFI, Secure Boot aus) und als `root`
   anmelden (Live-System: ohne Passwort).
2. Installierte Systeme finden:

   ```
   veyra-recovery liste
   /dev/nvme0n1: Root /dev/nvme0n1p2 (ext4), PARTUUID …, EFI-Systempartition /dev/nvme0n1p1
   ```

3. Nur prüfen (ändert nichts, hängt nur lesend ein):

   ```
   veyra-recovery pruefe /dev/nvme0n1
   ```

   Gemeldet werden: Fehler im Dateisystem (e2fsck), ein unterbrochener Paketvorgang,
   fehlende oder veränderte Paketdateien, Probleme der EFI-Systempartition (systemd-boot,
   `loader.conf`, Booteinträge mit fehlendem Kernel oder falscher Root-Angabe) und
   Kontenprobleme (`veyra-kontencheck`).

4. Reparieren (fragt nach dem Gerätenamen):

   ```
   veyra-recovery repariere /dev/nvme0n1
   ```

5. Neu starten, Live-Medium entfernen.

## Was `repariere` tut

| Schritt | Reparatur |
|---|---|
| Dateisystem | `e2fsck -f -y` auf der nicht eingehängten Root-Partition |
| Paketvorgang | `vpkg recover` nimmt einen unterbrochenen Vorgang zurück |
| Paketdateien | holt fehlende oder veränderte Dateien aus dem Live-System, aber nur, wenn dort genau die Datei liegt, die das installierte Paket verlangt (gleiche SHA-256). Sonst: Hinweis, das Paket neu zu installieren |
| Konfiguration | Dateien unter `/etc` bleiben, wie sie sind, auch wenn sie geändert wurden |
| systemd-boot | `EFI/BOOT/BOOTX64.EFI`, `EFI/systemd/systemd-bootx64.efi` und `loader/loader.conf` kommen aus dem Zielsystem zurück, wenn sie fehlen oder kaputt sind |
| Booteinträge | falsche Root-Angabe wird zu `root=PARTUUID=` der eigenen Partition; fehlt der Kernel, kommt er aus `/usr/lib/modules/VERSION/vmlinuz` des Zielsystems. Ein reparierter Eintrag gilt wieder als ungeprüft (`+3`). Einträge, deren Kernel es nicht mehr gibt, werden als schlecht markiert (`+0`). Fehlt ein Eintrag für den installierten Kernel, wird er angelegt |
| Konten | nur geprüft, nie geändert |

## Kernel-Rückfall

Startet ein neuer Kernel zwar, ist aber unbrauchbar, fällt man auf den vorigen zurück:

```
veyra-recovery kernel /dev/nvme0n1 liste
veyra-recovery kernel /dev/nvme0n1 zurueck            # Standard-Kernel als schlecht markieren
veyra-recovery kernel /dev/nvme0n1 entferne VERSION
```

`zurueck` verweigert, wenn es keinen anderen brauchbaren Kernel gibt. Startet ein neuer
Kernel gar nicht, braucht es das nicht: nach drei Fehlstarts nimmt systemd-boot von selbst
den letzten guten (siehe `veyra-kernel-update`).

## Logs

```
veyra-recovery logs /dev/nvme0n1          # Warnungen und Fehler des letzten Starts
veyra-recovery logs /dev/nvme0n1 --alle   # alle Meldungen
```

## Sicherheit

- Alle schreibenden Befehle verlangen den Gerätenamen (oder `--bestaetigt GERÄT`).
- Eingehängte Systeme, also auch das gerade laufende, werden abgelehnt.
- Partitionen werden nie angelegt, verändert oder formatiert.

## Nachweis

Der CI-Job „Live-ISO, Boot-Test von CD und Recovery“ (`image/recovery-test.py`) installiert
Veyra auf eine leere virtuelle Platte, beschädigt dort den Booteintrag und `/usr/bin/less`,
zeigt, dass die Platte nicht mehr startet, repariert sie aus der Live-ISO und startet sie
danach wieder. Das ist ein Test in QEMU, nicht auf echter Hardware.
