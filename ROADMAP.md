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
- **Schritte:** LLMNR und MulticastDNS in einem Drop-in für systemd-resolved abschalten;
  Selbsttest listet mit `ss -tuln` alle lauschenden Sockets und meldet jeden, der nicht
  an Loopback hängt und kein DHCP-Antwort-Port ist.
- **Abhängigkeiten/Risiken:** hängt an P2-1 (Netzwerk). Keine Firewall: ein später
  installierter Dienst kann wieder Ports öffnen; der Test prüft nur den Zustand nach dem
  Start des Grundsystems.
- **Akzeptanz:** Selbsttest meldet „Offene Ports: ok“, außer Loopback nur die Antwort-Ports
  der DHCP-Clients (UDP 68/546).
- **Testnachweis:** CI-Lauf [38697548625](https://github.com/MagieGubi/Veyra-OS/actions/runs/38697548625): „VEYRA-SELBSTTEST: Offene Ports: ok (nur Loopback)“ im
  Abbild und in der Live-ISO (nur QEMU, nicht auf echter Hardware). Der Filter erkannte
  lokal mit einer Beispielausgabe von `ss` den LLMNR-Port 5355.

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
- **Testnachweis:** noch keiner. Geplant: Selbsttest prüft das Passwortfeld von root je
  Variante.

## P1: Stabilität, Tests, VPKG

### P1-1 Transaktionen mit Rücknahme und Absturz-Wiederherstellung ✅
- **Ziel/Begründung:** Ein Abbruch (Fehler, Stromausfall) mitten in Installation, Update
  oder Entfernen ließ halb geschriebene Dateien und eine falsche Paketdatenbank zurück.
- **Dateien:** `packages/base/vpkg/vpkg` (Txn, transaction, recover),
  `tests/vpkg/vpkg-test.sh`, `packages/test/veyra-selftest/recipe.sh`, `docs/vpkg.md`.
- **Schritte:** Journal unter `/var/lib/vpkg/txn` mit Sicherung jeder ersetzten Datei,
  Rücknahme bei Fehler, `vpkg recover` und automatische Rücknahme nach einem Absturz;
  Testhaken `VPKG_TEST_ABBRUCH` für Abbrüche an jeder Stelle.
- **Abhängigkeiten/Risiken:** Install-Skripte laufen nach dem Abschluss und werden nicht
  zurückgenommen (P1-6). Rücknahme braucht freien Platz für die Sicherungen.
- **Akzeptanz:** Abbruch an jeder Stelle hinterlässt den vorherigen Zustand (Dateien,
  Konfiguration, Datenbank); nach einem Absturz meldet `check` ihn und `recover` räumt auf.
- **Testnachweis:** Tests 16 bis 19, Selbsttest „vpkg Abbruch und Ruecknahme: ok“ in den
  CI-Läufen 38451902869 und [38697548625](https://github.com/MagieGubi/Veyra-OS/actions/runs/38697548625) (Abbild und Live-ISO).

### P1-2 Strenge Manifestprüfung ✅
- **Ziel/Begründung:** Ein signiertes, aber fehlerhaftes oder bösartig gebautes Paket hätte
  Rechte, doppelte Pfade oder Einträge in der Paketdatenbank selbst setzen können.
- **Dateien:** `packages/base/vpkg/vpkg` (Manifestprüfung), `tests/vpkg/vpkg-test.sh`.
- **Schritte:** Pfade, Typen, Rechte, Prüfsummen und Abhängigkeitsnamen jedes Eintrags
  prüfen; Pfade unter `var/lib/vpkg` nur als Verzeichnis zulassen; Meldungen statt
  Python-Tracebacks.
- **Abhängigkeiten/Risiken:** strengere Regeln können ältere eigene Pakete ablehnen, daher
  prüft ein Test alle eigenen Pakete.
- **Akzeptanz:** manipulierte Manifeste werden abgelehnt, alle eigenen Pakete bestehen.
- **Testnachweis:** Tests 20 und 25, CI-Läufe 38451902869 und [38697548625](https://github.com/MagieGubi/Veyra-OS/actions/runs/38697548625).

### P1-3 Versionsbedingungen in Abhängigkeiten ⬜
- **Ziel/Begründung:** `depends` kennt nur Namen. Ein Paket, das `liba>=2` braucht, lässt
  sich heute gegen `liba 1` installieren; inkompatible Abhängigkeiten bleiben unbemerkt.
- **Dateien:** `build/scripts/vpkg-build` (Rezeptsyntax), `packages/base/vpkg/vpkg`
  (resolve, remove, check), `docs/vpkg-format.md`.
- **Schritte:** Syntax `name>=ver`, `name=ver`, `name<ver` in `depends`; Vergleich mit
  dem vorhandenen `vercmp`; Prüfung beim Installieren, Entfernen und in `check`.
- **Abhängigkeiten/Risiken:** Formaländerung: ältere VPKG-Versionen lehnen neue Einträge
  ab (`NAME_RE`). Migration: erst VPKG aktualisieren, dann Pakete mit Bedingungen.
- **Akzeptanz:** Installation gegen eine zu alte Abhängigkeit und ein Update, das eine
  Bedingung verletzt, werden mit klarer Meldung abgelehnt.
- **Testnachweis:** noch keiner; geplant sind Tests für erfüllte, nicht erfüllte und
  durch Update verletzte Bedingungen.

### P1-4 Reproduzierbarkeit der Basispakete und des Abbilds prüfen ⬜
- **Ziel/Begründung:** Nur der Kernel wird nachweislich bit-identisch gebaut. Für Pakete
  und Abbild ist es Ziel (`SOURCE_DATE_EPOCH`, feste UUIDs), aber nicht geprüft.
- **Dateien:** `.github/workflows/toolchain.yml`, `build/scripts/ci-stage4b.sh`,
  `image/build-image.sh`.
- **Schritte:** zweiten Bau von Teilen (zuerst `vpkg`, `veyra-*`, dann Stufe 4b) in
  einem eigenen Job, SHA-256 vergleichen, Abweichungen mit `diffoscope` dokumentieren.
- **Abhängigkeiten/Risiken:** Stufe 4b dauert Stunden und verlängert jeden Lauf; zuerst
  nur kleine Pakete. Abweichungen können in fremden Build-Systemen liegen.
- **Akzeptanz:** ein CI-Job vergleicht die Prüfsummen und schlägt bei Abweichung fehl.
- **Testnachweis:** teilweise: VPKG-Test 1 baut `veyra-release` zweimal identisch
  (022def38…); für Basispakete und Abbild noch keiner.

### P1-5 GitHub Actions auf aktuelle Laufzeit ⬜
- **Ziel/Begründung:** Jeder Lauf warnt, dass `actions/upload-artifact@v4` und
  `actions/download-artifact@v4` noch auf Node.js 20 laufen. Sobald GitHub Node 20
  abschaltet, bricht der Build.
- **Dateien:** `.github/workflows/toolchain.yml`.
- **Schritte:** auf eine Version wechseln, die Node.js 24 unterstützt, sobald geprüft ist,
  dass Artefaktnamen und Aufbewahrung gleich bleiben.
- **Abhängigkeiten/Risiken:** neue Hauptversionen können das Artefaktformat ändern; ein
  Fehler fällt erst im nächsten vollen Lauf auf.
- **Akzeptanz:** CI grün ohne Node-20-Warnung, Artefakte wie bisher herunterladbar.
- **Testnachweis:** noch keiner.

### P1-6 `pre_remove` und fehlgeschlagene Install-Skripte ⬜
- **Ziel/Begründung:** Install-Skripte (`post_install`) laufen nach dem Abschluss und
  lassen sich nicht zurücknehmen; vor dem Entfernen gibt es keinen Haken (z. B. Dienst
  stoppen).
- **Dateien:** `packages/base/vpkg/vpkg`, `build/scripts/vpkg-build`,
  `docs/vpkg-format.md`, `tests/vpkg/vpkg-test.sh`.
- **Schritte:** `pre_remove` im Skript erlauben und vor dem Entfernen ausführen; bei einem
  scheiternden Skript klare Meldung und dokumentierter Zustand (Paket bleibt eingetragen,
  `check` meldet es).
- **Abhängigkeiten/Risiken:** Skripte laufen als root im Zielsystem; mehr Haken heißt mehr
  Angriffsfläche. Baut auf P1-1 auf.
- **Akzeptanz:** Tests mit scheiterndem `post_install` und `pre_remove` zeigen eine klare
  Meldung und einen konsistenten Zustand.
- **Testnachweis:** noch keiner.

### P1-7 Diagnose bei fehlgeschlagenem Start 🟡
- **Ziel/Begründung:** Schlug der Boot-Test fehl, gab es nur das rohe Konsolen-Log mit
  hunderten Zeilen. Wie weit der Start kam und woran er scheiterte, musste man selbst
  heraussuchen; für Logs vom echten Rechner gab es gar keine Auswertung.
- **Dateien:** `image/boot-diagnose.sh` (neu), `image/boot-test.sh`,
  `tests/boot/diagnose-test.sh` (neu), `.github/workflows/toolchain.yml`,
  `docs/hardware-test.md`.
- **Schritte:** Skript bestimmt die erreichte Stufe (Firmware, Kernel, Init, systemd,
  Login, Selbsttest) und listet bekannte Fehlermuster mit den passenden Zeilen;
  `boot-test.sh` ruft es bei jedem Fehlschlag auf; Tests mit künstlichen Logs je Stufe im
  Job „VPKG-Tests“.
- **Abhängigkeiten/Risiken:** nur lesend, ändert am Start nichts und braucht keinen
  Neubau von Kernel oder Paketen. Mustererkennung kann neue Fehlerarten übersehen.
- **Akzeptanz:** jede Stufe wird in einem Test erkannt; ein grünes CI-Log ergibt keinen
  falschen Fehlerhinweis außer echten Befunden.
- **Testnachweis:** lokal 9 von 9 Diagnose-Tests, shellcheck sauber. Auf die echten
  Konsolen-Logs aus Lauf 38697548625 angewandt: Stufe „Selbsttest“, einziger Hinweis ist
  ein echter Befund (`regulatory.db` fehlt, gehört zu P2-3/P2-4). CI-Lauf steht aus.

## P2: Hardware und Netzwerk

### P2-1 Netzwerk per Kabel ✅
- **Ziel/Begründung:** Ohne Netzwerk keine Updates aus einem Online-Repository und keine
  Tests von Diensten.
- **Dateien:** `packages/base/veyra-netzwerk/recipe.sh`,
  `packages/test/veyra-selftest/recipe.sh`, `image/boot-test.sh`, `image/build-iso.sh`.
- **Schritte:** systemd-networkd mit DHCP für jede Kabel-Netzwerkkarte, systemd-resolved
  als DNS; Selbsttest prüft Adresse, Router und DNS; Boot-Test schaltet die VM über den
  ACPI-Ausschalter aus und prüft das saubere Herunterfahren.
- **Abhängigkeiten/Risiken:** nur Kabel; nur mit der QEMU-Karte e1000e geprüft.
- **Akzeptanz:** in der VM Adresse per DHCP, Router, DNS, Namensauflösung; Herunterfahren
  ohne fehlgeschlagene Einheit innerhalb von 90 s.
- **Testnachweis:** CI-Lauf 38543785626 und [38697548625](https://github.com/MagieGubi/Veyra-OS/actions/runs/38697548625): DHCP-Adresse, Router, DNS,
  Namensauflösung in Abbild und Live-ISO; sauberes Herunterfahren in etwa 1 s.

### P2-2 Test auf Adrians Laptop (MSI Katana 15) 🔧
- **Ziel/Begründung:** Erster Start auf echter Hardware vom USB-Stick, ohne die interne
  SSD zu ändern. Alle bisherigen Messwerte stammen aus QEMU.
- **Dateien:** `kernel/config/veyra-30-hardware.config`, `image/build-image.sh`,
  `docs/hardware-test.md`.
- **Schritte (vorbereitet):** Treiber für NVMe, xHCI/UAS, i915, simpledrm, Tastatur,
  Touchpad; Datenpartition `VEYRA-DATEN` mit Bericht und Kernel-Log; `root=` und `fstab`
  verweisen nur auf `PARTLABEL=veyra-*`; der Selbsttest liest die NVMe-SSD nur
  (`dd … of=/dev/null`). Offen: Adrian bootet den Stick nach der Anleitung.
- **Abhängigkeiten/Risiken:** Secure Boot muss aus (Kernel nicht von Microsoft signiert);
  der Stick wird gelöscht; NVIDIA-Grafik bleibt aus.
- **Akzeptanz:** `veyra-messung.txt` vom Stick mit „VEYRA-SELBSTTEST: OK“ und erkannter
  SSD, Grafik, Tastatur.
- **Testnachweis:** noch keiner (nie auf echter Hardware gestartet).

### P2-3 Firmware-Paket ⬜
- **Ziel/Begründung:** Ohne Firmware bleiben Intel-WLAN (`iwlwifi`) und Teile der
  Intel-Grafik (DMC) aus. Der Kernel bringt die Treiber schon mit.
- **Dateien:** neues Rezept `packages/base/linux-firmware-intel/recipe.sh`, Eintrag in
  den gepinnten Quellen, `image/build-image.sh`.
- **Schritte:** linux-firmware-Archiv herunterladen, prüfen und pinnen (noch nicht
  geschehen); Paket nur mit den nötigen Dateien; Lizenzdateien mitliefern.
- **Abhängigkeiten/Risiken:** Lizenz (weiterverteilbar, aber nicht frei), Größe.
- **Akzeptanz:** Dateien im Abbild, `vpkg check` grün; Laden nur auf echter Hardware
  prüfbar.
- **Testnachweis:** noch keiner.

### P2-4 WLAN ⬜ (hängt an P2-3)
- **Ziel/Begründung:** Der Laptop soll ohne Kabel ins Netz.
- **Dateien:** neues Rezept für iwd, `packages/base/veyra-netzwerk/recipe.sh`.
- **Schritte:** iwd bauen und als Paket, Einstellung über `iwctl`, Adresse weiter über
  systemd-networkd.
- **Abhängigkeiten/Risiken:** braucht P2-3 und echte Hardware; QEMU hat kein WLAN.
- **Akzeptanz:** auf dem Laptop Verbindung mit einem WPA2/WPA3-Netz.
- **Testnachweis:** noch keiner.

### P2-5 Live-ISO in VirtualBox bestätigen 🔧
- **Ziel/Begründung:** Adrian testet in VirtualBox; bisher lief die ISO nur in QEMU.
- **Dateien:** `docs/virtualbox.md`, `image/build-iso.sh`.
- **Schritte:** Adrian lädt das Artefakt `veyra-live-iso` und startet es nach der
  Anleitung; Abweichungen (z. B. andere Netzwerkkarte) werden dann behoben.
- **Abhängigkeiten/Risiken:** VirtualBox nutzt standardmäßig eine andere Netzwerkkarte
  als QEMU; der Treiber dafür ist nicht in QEMU geprüft.
- **Akzeptanz:** Adrian meldet Login, „VEYRA-SELBSTTEST: OK“ und Netzwerk.
- **Testnachweis:** noch keiner.

## P3: Installation, Recovery, Updates

### P3-1 Online-Repository ⬜ (hängt an P0-1)
- **Ziel/Begründung:** Updates sollen ohne neues Abbild ins System kommen.
- **Dateien:** `.github/workflows/toolchain.yml`, `image/build-image.sh` (`/etc/vpkg/repo`),
  `docs/vpkg.md`.
- **Schritte:** signiertes Repository dauerhaft per HTTPS veröffentlichen (z. B. GitHub
  Pages oder Releases); Download in VPKG mit Prüfung über den signierten Index.
- **Abhängigkeiten/Risiken:** braucht P0-1 (erledigt) und P2-1; ohne Ablaufdatum im Index
  kann ein Spiegel neue Stände zurückhalten.
- **Akzeptanz:** der Selbsttest führt `vpkg upgrade` gegen das Online-Repository aus.
- **Testnachweis:** noch keiner.

### P3-2 Installation auf eine Festplatte ⬜
- **Ziel/Begründung:** Veyra läuft bisher nur als fertiges Abbild oder Live-System.
- **Dateien:** neues Skript `image/install.sh`, `docs/installation.md`.
- **Schritte:** Ziel nur nach ausdrücklicher Auswahl, Partitionieren, Basispakete über
  VPKG, Kernel auf die ESP.
- **Abhängigkeiten/Risiken:** höchstes Risiko für Benutzerdaten; nur in QEMU mit leerer
  virtueller Platte testen, nie automatisch auf echter Hardware.
- **Akzeptanz:** Installation in eine leere virtuelle Platte bootet bis zum Selbsttest OK.
- **Testnachweis:** noch keiner.

### P3-3 Bootloader, UKI, Secure Boot, Btrfs-Snapshots ⬜
- **Ziel/Begründung:** Mehrere Kernel, Rückfall auf einen alten Stand und Start mit
  eingeschaltetem Secure Boot.
- **Dateien:** `packages/core/systemd/recipe.sh`, `image/build-image.sh`, neue Rezepte.
- **Schritte:** prüfen, ob das systemd-Paket systemd-boot baut (nicht geprüft); `ukify`
  ist dort abgeschaltet (`-D ukify=disabled`); eigene Secure-Boot-Schlüssel und
  Signierkette.
- **Abhängigkeiten/Risiken:** erst nach P3-2; Eingriff in den Startweg, nur in QEMU.
- **Akzeptanz:** Start über systemd-boot mit Auswahl zweier Kernel in QEMU.
- **Testnachweis:** noch keiner.

### P3-4 Rettungssystem ⬜
- **Ziel/Begründung:** Ein kaputtes installiertes System soll sich reparieren lassen.
- **Dateien:** `docs/rettung.md`, `packages/test/veyra-selftest/recipe.sh`.
- **Schritte:** Live-ISO als Rettungssystem dokumentieren (Platte einhängen,
  `vpkg --root … recover`, `vpkg --root … check`).
- **Abhängigkeiten/Risiken:** sinnvoll erst mit P3-2.
- **Akzeptanz:** in QEMU repariert die Live-ISO eine absichtlich abgebrochene
  Installation auf einer virtuellen Platte.
- **Testnachweis:** noch keiner.

## P4: Benutzerfreundlichkeit und Erweiterungen

### P4-1 Deutsche Tastatur und Sprache ⬜
- **Ziel/Begründung:** Adrian nutzt eine deutsche Tastatur; die Konsole ist US-Layout.
- **Dateien:** `image/build-image.sh`, `image/build-iso.sh` (das Paket `kbd` mit den
  Tastaturbelegungen ist schon gebaut).
- **Schritte:** `/etc/vconsole.conf` mit `KEYMAP=de-latin1`, Locale `de_DE.UTF-8` als
  Option.
- **Abhängigkeiten/Risiken:** gering; der Boot-Test darf sich dadurch nicht ändern.
- **Akzeptanz:** `localectl` zeigt `de-latin1`; Selbsttest weiter OK.
- **Testnachweis:** noch keiner.

### P4-2 Benutzerkonten statt root ⬜ (hängt an P0-3)
- **Ziel/Begründung:** Arbeiten ohne root-Rechte.
- **Dateien:** `image/build-image.sh`, später Installer (P3-2).
- **Schritte:** Benutzer beim ersten Start anlegen, root gesperrt.
- **Abhängigkeiten/Risiken:** braucht P0-3; `sudo` oder ein Ersatz ist noch nicht gebaut.
- **Akzeptanz:** Anmeldung als Benutzer, root-Anmeldung abgelehnt.
- **Testnachweis:** noch keiner.

### P4-3 Optionale Desktop-Profile ⬜
- **Ziel/Begründung:** Ziel aus der Veyra-Spezifikation: Desktop oder Fenstermanager bei
  der Installation wählbar, Standard minimal, kitty als Terminal.
- **Dateien:** neue Paketgruppen und Rezepte (Wayland, Mesa, ein Compositor).
- **Schritte:** zuerst Grafikstapel (Mesa, libdrm, Wayland), dann ein kleiner Compositor.
- **Abhängigkeiten/Risiken:** sehr viele neue Pakete aus Quellcode; jede Sicherheitslücke
  muss Veyra selbst nachbauen. Erst nach P3.
- **Akzeptanz:** Profil startet in QEMU bis zu einer grafischen Sitzung.
- **Testnachweis:** noch keiner.
