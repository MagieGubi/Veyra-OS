# Veyra OS 0.5: Analyse und Implementierungsplan

Stand: 16.11.2026. Grundlage ist der Quellcode auf `main` (Commit 79f9f5e) und der
CI-Lauf [43856635308](https://github.com/MagieGubi/Veyra-OS/actions/runs/43856635308),
nicht die Häkchen in der ROADMAP. Auftrag: „Veyra OS 0.5 – First Installable System“.

## 1. Was nachweislich funktioniert (im Code und im CI geprüft)

| Bereich | Stand im Code | Nachweis |
| --- | --- | --- |
| Bau aus Quellcode | Stufen 1 bis 5 in `toolchain.yml`, Quellen per Signatur oder Prüfsumme gepinnt (`check-pinned.sh`: 0 offen) | alle 12 Jobs grün |
| Kernel 6.18.56-veyra2 | zwei unabhängige Builds, bit-identisch | Job „Kernel reproduzierbar?“ |
| VPKG 0.4.1 | Abhängigkeiten mit Versionsbedingungen, Konflikte, Transaktionen mit Journal und `recover`, strenge Manifestprüfung, Ed25519 für Pakete und Index, Downgrade-Schutz, HTTP(S)-Quelle (`--repo https://…`) | 28/29 Tests, Selbsttest in der VM |
| Live-ISO | eigenes Init, SquashFS, Overlay | Boot von virtueller CD, Selbsttest OK |
| Installer `veyra-install` | GPT, ESP (FAT32 per eigenem Schreiber), ext4, Bestätigung per Gerätenamen, erkennt vorhandene Systeme | 15 Tests; Installation auf leere 8-GiB-Platte und Boot in QEMU |
| Konten | root gesperrt bis zur Ersteinrichtung (Test- und installiertes System), su nur für `wheel`, Kontenprüfung | Selbsttest „Konten und Rechte: ok“ |
| Netzwerk | DHCP und DNS per systemd-networkd/resolved, keine offenen Ports | Selbsttest in QEMU (e1000e) |

## 2. Was nur vorbereitet oder gar nicht vorhanden ist

1. **Ersteinrichtung und Anmeldung nie im laufenden System geprüft.** Der Boot-Test
   startet QEMU ohne Bildschirm; die Eingabe an Konsole 1 testet nur
   `tests/konten/konten-test.sh` mit einem künstlichen System. Ebenso fehlen ein
   **Neustart** der installierten Platte und eine **echte Anmeldung**. Das sind drei
   Punkte der Definition of Done.
2. **Bootweg:** Der Kernel trägt `root=PARTLABEL=veyra-root` fest eingebaut und startet
   über den Fallback-Pfad `\EFI\BOOT\BOOTX64.EFI`. Das funktioniert, hat aber Grenzen:
   - Zwei Datenträger mit `veyra-root` (z. B. installierte Platte und USB-Testabbild)
     sind nicht unterscheidbar. Der Installer lehnt das beim Installieren ab, beim
     späteren Start schützt nichts.
   - Kein Rückfall auf einen alten Kernel, kein Kernel-Update auf der ESP.
   - Die ESP ist im installierten System nicht eingehängt. Der Kernel kann FAT
     (`CONFIG_VFAT_FS=y`), nur fehlt der Eintrag in der fstab.
3. **Installer:** kopiert das Entwicklungsabbild mit Compiler (knapp 6 GiB). Er fragt
   keine Konten ab (das macht erst der erste Start). Bei einem Fehler stellt er die
   alte Partitionstabelle nicht wieder her.
4. **VPKG (P1-6):** Ein scheiterndes `post_install` lässt das Paket eingetragen, ohne dass
   `check` das später zeigt. `pre_remove` gibt es nicht.
   `vpkg-build` muss dafür geändert werden; das löst den mehrstündigen Neubau von
   Stufe 4b aus.
5. **Online-Repository (P3-1):** VPKG kann HTTP(S)-Quellen, der Index wird signiert. Es
   gibt aber keinen dauerhaften Ort; das Repository lebt als CI-Artefakt 7 Tage.
   Beim Umsetzen gefunden: Das Basissystem hat **keine Wurzelzertifikate**, https zu einem
   öffentlichen Server wäre im laufenden System immer gescheitert. Behoben mit dem Paket
   `veyra-zertifikate` (gepinntes certifi-Archiv von PyPI) und einer TLS-Prüfung im
   Selbsttest.
6. **GitHub Actions (P1-5):** `upload-artifact@v4`, `download-artifact@v4`, `cache@v4`
   laufen auf Node 20; GitHub warnt in jedem Lauf. Vorhanden sind v7, v8 und v6.
7. **Reproduzierbarkeit (P1-4):** Für die Basispakete und das Abbild ungeprüft.
8. **Hardware (P2-3, P2-4):** `CONFIG_IWLWIFI=m`, aber keine Firmware und kein WLAN-Dienst
   (iwd). Echte Hardware nie getestet.
9. **PAM, sudo (P1-8):** fehlen. Für 0.5 nicht nötig: shadow ohne PAM, `su` nur für
   `wheel`. Nötig erst für einen grafischen Login-Manager.
10. **Version:** `veyra-release` steht noch auf 0.1.

## 3. Sicherheitsbefunde

- Keine offenen Ports, keine Telemetrie, root im Test- und installierten System gesperrt.
- Install-Skripte laufen als root im Zielsystem. Das ist nötig; sie stammen nur aus
  signierten Paketen.
- Der private Signaturschlüssel liegt nur im Secret `VPKG_SIGNING_KEY` und wird nach dem
  Signieren gelöscht.
- Offen: Ein scheiterndes Install-Skript bleibt unsichtbar (Punkt 4). Das installierte
  System enthält den Compiler (Punkt 3), was die Angriffsfläche vergrößert.

## 4. Plan für 0.5 (Reihenfolge nach Definition of Done)

| Schritt | Phase | Inhalt | Test |
| --- | --- | --- | --- |
| 1 | B | GitHub Actions auf Node-24-Versionen (P1-5) | CI grün ohne Warnung |
| 2 | C | **QEMU-Test der Installation mit Eingaben:** Ersteinrichtung an Konsole 1 per Tastatur (QEMU-Monitor), Anmeldung als neuer Benutzer und als root über die serielle Konsole, `su` nur mit Passwort, Neustart von der installierten Platte, zweiter Selbsttest | `image/install-test.py` im CI |
| 3 | C | Installer: Konten optional schon bei der Installation (ruft `veyra-einrichtung --root` auf), ESP in der fstab (`/efi`, `noauto`), Partitionstabelle bei Fehler vor dem Schreiben von Daten zurücksetzen | Installer-Tests |
| 4 | C | Bootweg nach der Entscheidung (siehe unten) | Boot-Test |
| 5 | D | VPKG: gescheitertes `post_install` im Paket vermerken, `check` meldet es; `pre_remove` (P1-6) | VPKG-Tests |
| 6 | D | Online-Repository vorbereiten: nur https (Zertifikat geprüft, keine Umleitung auf http, Größengrenzen), Test gegen einen lokalen HTTPS-Server, Wurzelzertifikate im System. Die feste Adresse in `/etc/vpkg/repo` kommt erst mit dem Ort (z. B. GitHub Pages), und der braucht deine Freigabe | VPKG-Tests, Selbsttest „TLS“ |
| 7 | E | Firmware-Paket (iwlwifi, aus dem gepinnten linux-firmware-Archiv mit Lizenzdateien), iwd für WPA2/WPA3 | Bau im CI; WLAN selbst nur auf echter Hardware prüfbar |
| 8 | F | Volle CI-Pipeline, Fehler beheben, Ergebnisse dokumentieren | CI grün |
| 9 | G | Version 0.5.0 (`veyra-release`, `/etc/os-release`), Release-Notizen | — |

Schritt 7 kommt nur, wenn 1 bis 6 stabil sind. Jeder Push und ein Release brauchen
deine ausdrückliche Freigabe.

## 5. Entscheidung: Bootweg für installierte Systeme

- **A (empfohlen für 0.5, umgesetzt als Standard bis zu deiner Antwort):** Kernel weiter direkt von der Firmware mit
  `PARTLABEL=veyra-root`, ESP in der fstab. Dazu prüft eine Startprüfung, ob mehr als eine
  `veyra-root`-Partition angeschlossen ist, und warnt. Kleine Änderung, kein Neubau von
  systemd.
- **B (geplant für 0.6):** systemd-boot mit Einträgen per `PARTUUID`, zwei Kernel zur
  Auswahl, Kernel-Updates auf der ESP. Dafür muss systemd mit Bootloader gebaut werden
  (braucht das Python-Modul pyelftools als neues gepinntes Paket) und Stufe 4b neu.
