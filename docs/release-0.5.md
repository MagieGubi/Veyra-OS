# Veyra OS 0.5.0: First Installable System

Stand: 17.11.2026. Nachweis: CI-Lauf
[44114798590](https://github.com/MagieGubi/Veyra-OS/actions/runs/44114798590), alle Jobs grün.
**Alle Laufzeit-Nachweise stammen aus QEMU (KVM) im CI. Auf echter Hardware ist Veyra 0.5
nie gestartet worden.**

## Was 0.5 kann

- **Installieren:** `veyra-install installiere /dev/sdX` aus der Live-ISO legt GPT mit
  EFI-Partition (FAT32) und ext4 an und kopiert das System. Geschrieben wird erst, wenn
  der Gerätename eingetippt ist. Scheitert das Schreiben der Partitionstabelle, stellt der
  Installer die alte wieder her. root-Passwort und Benutzer lassen sich schon bei der
  Installation festlegen (`--konten`) oder beim ersten Start.
- **Erster Start:** root ist gesperrt, bis die Ersteinrichtung an Konsole 1 ein Passwort
  setzt; sie legt auf Wunsch einen Benutzer in `wheel` an. Nur `wheel` darf `su`.
- **Nachgewiesen im CI** (`image/install-test.py`): Installation auf eine leere virtuelle
  8-GiB-Platte, Ersteinrichtung per Tastatur an Konsole 1, root ohne Passwort abgewiesen,
  Anmeldung als neuer Benutzer, `/etc/shadow` für ihn nicht lesbar, `su` mit dem
  root-Passwort ergibt UID 0, Herunterfahren, Neustart ohne erneute Ersteinrichtung,
  Anmeldung als root, systemd meldet `running`, Root ist ext4 der installierten Platte.
- **VPKG 0.5:** `pre_remove`; ein gescheitertes Install-Skript bleibt sichtbar
  (`vpkg check`, `vpkg rerun-script`); Netzquellen nur über https mit Zertifikatsprüfung,
  keine Umleitung auf http, Größengrenzen. Dazu weiterhin Abhängigkeiten mit
  Versionsbedingungen, Transaktionen mit Rücknahme, Ed25519-Signaturen für Pakete und
  Repository-Index, Schutz vor alten Index-Ständen und Downgrades.
- **Wurzelzertifikate:** neues Paket `veyra-zertifikate` (Mozilla-CA-Bündel aus certifi,
  gepinnt). Vorher fehlten sie, https zu öffentlichen Servern war im System unmöglich.
  Der Selbsttest prüft eine echte TLS-Verbindung.
- **Bootweg A:** Die Firmware startet den Kernel direkt (`root=PARTLABEL=veyra-root`).
  Hängen zwei Veyra-Platten am Rechner, warnt `veyra-rootpruefung` auf der Konsole und
  über der Anmeldung. Die EFI-Partition steht in der fstab (`/efi`, `noauto`).
- **CI:** GitHub Actions auf Node-24-Versionen.

## Bekannte Grenzen

- Nie auf echter Hardware gestartet; Testanleitung: [hardware-test.md](hardware-test.md).
- Kein WLAN und keine Firmware (kommt in 0.6), kein Bluetooth, kein Audio, keine Firewall,
  keine grafische Oberfläche.
- Kein Bootloader, kein Kernel-Rückfall, kein Secure Boot; zwei Veyra-Platten sind nicht
  unterscheidbar (systemd-boot mit `PARTUUID` ist für 0.6 geplant).
- Kein dauerhaftes Online-Repository; Pakete und Abbilder gibt es als CI-Artefakte
  (Abbilder 7 Tage).
- Das installierte System enthält den Compiler und Entwicklungsdateien (knapp 6 GiB).
- Kein PAM, kein `sudo`.
- Im ersten CI-Lauf hing das Herunterfahren einmal 90 s (nicht wiederholbar); der Test
  schlägt jetzt fehl, wenn es länger als 60 s dauert, und nennt den Dienst.
- Reproduzierbar gebaut wird nachweislich nur der Kernel.

## Artefakte (CI-Lauf, Anmeldung bei GitHub nötig)

| Artefakt | Inhalt |
| --- | --- |
| `veyra-live-iso` | `veyra-0.5-live.iso`: Live-System mit Installer |
| `veyra-0.5-test` | Testabbild für USB-Stick (root gesperrt, Ersteinrichtung) |
| `veyra-virtualbox` | `veyra-0.5.vdi` für VirtualBox |
| `veyra-repo` | signiertes Paket-Repository |

## Komponenten

Kernel 6.18.56-veyra2, VPKG 0.5, Installer 0.3, veyra-konten 0.2, veyra-zertifikate
2026.10.23, Selbsttest 0.7, Basissystem: 68 Pakete nach LFS 12.4 (glibc 2.42, GCC 15.2.0,
systemd 257.8).
