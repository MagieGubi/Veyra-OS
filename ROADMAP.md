# Veyra OS: Roadmap

Stand: 15.10.2026. Diese Datei beschreibt den **tatsächlichen** Stand. Eine Aufgabe gilt
erst als erledigt, wenn ihre Akzeptanzkriterien nachweislich erfüllt sind (CI-Lauf,
Testausgabe). Ausführliche Begründungen und Messwerte: [docs/phase6.md](docs/phase6.md).

Status: ✅ erledigt (mit Nachweis) · 🟡 umgesetzt, Nachweis steht aus · 🔧 vorbereitet ·
⬜ offen

## Ist-Zustand in Kürze

| Bereich | Stand | Nachweis |
| --- | --- | --- |
| Toolchain, Basissystem (68 Pakete, glibc bis systemd) | aus Quellcode gebaut, Quellen gepinnt und geprüft | CI, `build/scripts/check-pinned.sh` |
| Kernel 6.18.56-veyra2 | zwei unabhängige Builds bit-identisch | CI-Job `kernel-reproducible` |
| Boot | UEFI, Kernel direkt als `BOOTX64.EFI`, ohne Bootloader und Initramfs; Live-ISO mit eigenem Init (`kernel/live/init.c`) | QEMU im CI (Festplatte und CD) |
| VPKG | Installieren, Entfernen, Abhängigkeiten, Ed25519-Signaturen, Transaktionen mit Rücknahme, signierter Repository-Index mit Stand- und Downgrade-Schutz (VPKG 0.3) | 25 Tests in `tests/vpkg/vpkg-test.sh` (einer nur ohne root) und 6 in `run.sh`, Selbsttest im gebooteten System |
| Netzwerk | Kabel per DHCP, Namensauflösung, außer Loopback keine offenen Ports | Selbsttest in QEMU |
| Echte Hardware | Treiber und USB-Test vorbereitet, **nie auf echter Hardware gestartet** | – |
| Installation auf Festplatte, Updates, Desktop | fehlen | – |

---

## P0: Kritische Fehler, Build-Fehler, Sicherheit

### P0-1 Repository-Index signieren, alte Indizes und Downgrades ablehnen ✅
- **Ziel/Begründung:** Der Index war unsigniert und ungeprüft. Ein Spiegel hätte alte, gültig
  signierte Pakete mit bekannten Fehlern als aktuell ausgeben, ein Paket hinter einem
  fremden Namen ausliefern oder über `vpkg install NAME` eine ältere Version einspielen
  können. Ein Dateiname im Index wurde ungeprüft als Pfad benutzt.
- **Dateien:** `packages/base/vpkg/vpkg` (Repo, LazyRepo, resolve, cmd_install, cmd_index),
  `build/scripts/sign-packages.sh`, `.github/workflows/toolchain.yml` (Repository-Schritt),
  `docs/vpkg.md`, `docs/vpkg-format.md`, `docs/signaturen.md`.
- **Schritte:** `index.toml.sig` Pflicht bei eingerichteten Schlüsseln; `stand` im Index,
  höchster signierter Stand je Quelle in `/var/lib/vpkg/repo-stand.json`; Index-Einträge
  prüfen (Name, Dateiname ohne Pfad, Prüfsumme, Version, Listen); geladenes Paket muss dem
  Eintrag entsprechen; Downgrade nur mit `--allow-downgrade`; CI signiert den Index und
  installiert zur Gegenprobe ein Paket daraus.
- **Abhängigkeiten/Risiken:** Format bleibt `format = 1` (neues Feld `stand`); signierter
  Index ohne `stand` wird abgelehnt (Migration: `vpkg index` neu laufen lassen). Kein
  Ablaufdatum: ein Spiegel kann neue Stände zurückhalten.
- **Akzeptanz:** unsignierter, veränderter, älterer und standloser Index abgelehnt;
  Pfad im Dateinamen, falsches Paket hinter Eintrag, kaputte Prüfsumme abgelehnt;
  Downgrade nur mit Option; CI-Repository hat `index.toml.sig` und die Gegenprobe läuft.
- **Testnachweis:** Tests 21 bis 24 in `tests/vpkg/vpkg-test.sh`, im CI-Lauf [38697548625](https://github.com/MagieGubi/Veyra-OS/actions/runs/38697548625) grün
  („Alle 25 VPKG-Tests bestanden“). Repository-Schritt im selben Lauf: „Pakete: 73,
  signiert: 73, Index signiert: ja“, Gegenprobe `vpkg install --repo … veyra-release` aus
  dem signierten Index erfolgreich.

### P0-2 Keine offenen Ports im Netz ✅
- **Ziel/Begründung:** systemd-resolved beantwortet standardmäßig LLMNR (Port 5355) auf
  jeder Netzwerkkarte; Veyra wäre damit im lokalen Netz ansprechbar, ohne dass es einen
  Grund dafür gibt.
- **Dateien:** `packages/base/veyra-netzwerk/recipe.sh` (`resolved.conf.d/50-veyra.conf`:
  LLMNR und mDNS aus), `packages/test/veyra-selftest/recipe.sh` (Prüfung mit `ss`).
- **Akzeptanz:** Selbsttest meldet „Offene Ports: ok“, außer Loopback nur die Antwort-Ports
  der DHCP-Clients (UDP 68/546).
- **Testnachweis:** CI-Lauf [38697548625](https://github.com/MagieGubi/Veyra-OS/actions/runs/38697548625): „VEYRA-SELBSTTEST: Offene Ports: ok (nur Loopback)“ im
  Abbild und in der Live-ISO (nur QEMU, nicht auf echter Hardware).

### P0-3 Root ohne Passwort im Abbild ⬜
- **Ziel/Begründung:** Das Entwicklungsabbild (auch der USB-Stick für den Hardware-Test und
  die Live-ISO) erlaubt die Anmeldung als root ohne Passwort. In der VM gewollt, auf einem
  echten Rechner ein Risiko, sobald Netzwerk und Dienste dazukommen.
- **Dateien:** `image/build-image.sh`, `image/build-iso.sh`, `docs/hardware-test.md`.
- **Schritte:** Abbild-Variante „dev“ (wie heute, nur für CI und VM) und „test“ (root
  gesperrt, Anmeldung nur an der lokalen Konsole mit einem beim ersten Start gesetzten
  Passwort); Variante sichtbar in `/etc/issue`.
- **Abhängigkeiten/Risiken:** `systemd-firstboot` ist im systemd-Paket abgeschaltet
  (`-D firstboot=false`); der Boot-Test braucht weiter einen automatisierbaren Weg.
- **Akzeptanz:** Im Test-Abbild ist `/etc/shadow` für root gesperrt; Boot-Test grün.
- **Testnachweis:** Selbsttest prüft das Passwortfeld von root je Variante.

## P1: Stabilität, Tests, VPKG

### P1-1 Transaktionen mit Rücknahme und Absturz-Wiederherstellung ✅
- **Dateien:** `packages/base/vpkg/vpkg` (Txn, transaction, recover).
- **Akzeptanz/Nachweis:** Tests 16 bis 18 (Abbruch an jeder Stelle, Absturz), Selbsttest
  „vpkg Abbruch und Rücknahme: ok“ in CI-Lauf 38451902869 (Abbild und Live-ISO).

### P1-2 Strenge Manifestprüfung ✅
- **Nachweis:** Tests 20 und 25 (manipulierte Manifeste, eigene Pakete), CI-Läufe 38451902869 und 38697548625.

### P1-3 Versionsbedingungen in Abhängigkeiten ⬜
- **Ziel/Begründung:** `depends` kennt nur Namen. Ein Paket, das `liba>=2` braucht, lässt
  sich heute gegen `liba 1` installieren; inkompatible Abhängigkeiten bleiben unbemerkt.
- **Dateien:** `build/scripts/vpkg-build` (Rezeptsyntax), `packages/base/vpkg/vpkg`
  (resolve, remove, check), `docs/vpkg-format.md`.
- **Schritte:** Syntax `name>=ver`, `name=ver`, `name<ver` in `depends`; Vergleich mit
  dem vorhandenen `vercmp`; Prüfung beim Installieren, Entfernen und in `check`.
- **Risiken:** Formaländerung: ältere VPKG-Versionen lehnen neue Einträge ab
  (`NAME_RE`). Migration: erst VPKG aktualisieren, dann Pakete mit Bedingungen.
- **Akzeptanz/Test:** neue Tests für erfüllte, nicht erfüllte und durch Update verletzte
  Bedingungen.

### P1-4 Reproduzierbarkeit der Basispakete und des Abbilds prüfen ⬜
- **Ziel/Begründung:** Nur der Kernel wird nachweislich bit-identisch gebaut. Für Pakete
  und Abbild ist es Ziel (`SOURCE_DATE_EPOCH`, feste UUIDs), aber nicht geprüft.
- **Dateien:** `.github/workflows/toolchain.yml`, `build/scripts/ci-stage4b.sh`,
  `image/build-image.sh`.
- **Schritte:** zweiten Bau von Teilen (zuerst `vpkg`, `veyra-*`, dann Stufe 4b) in
  einem eigenen Job, SHA-256 vergleichen, Abweichungen mit `diffoscope` dokumentieren.
- **Risiken:** Stufe 4b dauert Stunden; zuerst nur kleine Pakete.
- **Akzeptanz/Test:** CI-Job vergleicht Prüfsummen und schlägt bei Abweichung fehl.

### P1-5 GitHub Actions auf aktuelle Laufzeit ⬜
- **Begründung:** Jeder Lauf warnt, dass `actions/upload-artifact@v4` und
  `actions/download-artifact@v4` noch auf Node.js 20 laufen.
- **Schritte:** auf eine Version wechseln, die Node.js 24 unterstützt, sobald geprüft ist,
  dass Artefaktnamen und Aufbewahrung gleich bleiben.
- **Akzeptanz/Test:** CI grün ohne Node-20-Warnung.

### P1-6 `pre_remove` und fehlgeschlagene Install-Skripte ⬜
- **Begründung:** Install-Skripte laufen nach dem Abschluss und lassen sich nicht
  zurücknehmen; vor dem Entfernen gibt es keinen Haken (z. B. Dienst stoppen).
- **Akzeptanz/Test:** Tests mit scheiterndem Skript; klare Meldung, Zustand dokumentiert.

## P2: Hardware und Netzwerk

### P2-1 Netzwerk per Kabel ✅
- **Dateien:** `packages/base/veyra-netzwerk/`, Selbsttest.
- **Nachweis:** CI-Lauf 38543785626: DHCP-Adresse, Router, DNS, Namensauflösung in Abbild
  und Live-ISO; sauberes Herunterfahren über den ACPI-Ausschalter.

### P2-2 Test auf Adrians Laptop (MSI Katana 15) 🔧
- **Ziel:** Erster Start auf echter Hardware vom USB-Stick, ohne die interne SSD zu ändern.
- **Vorbereitet:** Treiber für NVMe, xHCI/UAS, i915, simpledrm, Tastatur, Touchpad
  (`kernel/config/veyra-30-hardware.config`); Datenpartition `VEYRA-DATEN` mit Bericht und
  Kernel-Log; Anleitung `docs/hardware-test.md`.
- **Schutz der vorhandenen Installation:** `root=` und `fstab` verweisen nur auf
  `PARTLABEL=veyra-*`; der Selbsttest liest die NVMe-SSD nur (`dd … of=/dev/null`).
- **Abhängigkeiten/Risiken:** Secure Boot muss aus (Kernel nicht von Microsoft signiert).
- **Akzeptanz/Test:** `veyra-messung.txt` vom Stick mit „VEYRA-SELBSTTEST: OK“ und
  erkannter SSD, Grafik, Tastatur.

### P2-3 Firmware-Paket ⬜
- **Ziel/Begründung:** Ohne Firmware bleiben Intel-WLAN (`iwlwifi`) und Teile der
  Intel-Grafik (DMC) aus. Der Kernel bringt die Treiber schon mit.
- **Schritte:** Paket `linux-firmware-intel` nur mit den nötigen Dateien aus dem
  gepinnten linux-firmware-Archiv; Lizenzdateien mitliefern.
- **Risiken:** Lizenz (weiterverteilbar, aber nicht frei), Größe.
- **Akzeptanz/Test:** Dateien im Abbild, `vpkg check` grün; Laden nur auf echter
  Hardware prüfbar.

### P2-4 WLAN ⬜ (hängt an P2-3)
- **Schritte:** iwd bauen und als Paket, Einstellung über `iwctl`.
- **Akzeptanz/Test:** auf dem Laptop Verbindung mit einem WPA2/WPA3-Netz.

### P2-5 Live-ISO in VirtualBox bestätigen 🔧
- **Vorbereitet:** `docs/virtualbox.md`. **Akzeptanz:** Adrian meldet Login und Netzwerk.

## P3: Installation, Recovery, Updates

### P3-1 Online-Repository ⬜ (hängt an P0-1)
- Paket-Repository statt nur als CI-Artefakt dauerhaft per HTTPS veröffentlichen
  (z. B. GitHub Pages oder Releases), `/etc/vpkg/repo` im Abbild setzen.
- **Akzeptanz/Test:** Selbsttest führt `vpkg upgrade` gegen das Online-Repository aus.

### P3-2 Installation auf eine Festplatte ⬜
- Installer-Skript: Ziel nur nach ausdrücklicher Auswahl, Partitionieren, Basispakete über
  VPKG, Kernel auf die ESP. Test nur in QEMU mit leerer virtueller Platte.

### P3-3 Bootloader, UKI, Secure Boot, Btrfs-Snapshots ⬜
- Erst nach P3-2. Voraussetzungen prüfen: ob das systemd-Paket systemd-boot überhaupt
  baut (nicht geprüft), `ukify` ist dort abgeschaltet (`-D ukify=disabled`); Secure Boot
  braucht eigene Schlüssel und eine Signierkette.

### P3-4 Rettungssystem ⬜
- Live-ISO als Rettungssystem dokumentieren (Platte einhängen, `vpkg recover`, `vpkg check`).

## P4: Benutzerfreundlichkeit und Erweiterungen

### P4-1 Deutsche Tastatur und Sprache ⬜
- `/etc/vconsole.conf` mit `KEYMAP=de-latin1`, Locale `de_DE.UTF-8` als Option im Abbild.

### P4-2 Benutzerkonten statt root ⬜ (hängt an P0-3)

### P4-3 Optionale Desktop-Profile ⬜
- Laut Architektur: genau eine Sitzung bei der Installation, kitty als Terminal. Braucht
  Grafikstack (Mesa, Wayland) als eigene Pakete; erst nach P3.
