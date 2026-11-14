# Veyra OS: Vollständige Systemanalyse

Stand: 14.11.2026, Commit 82f2dc1 plus die Änderungen dieser Iteration (Konten, Varianten).
Geprüft am Quellcode und an den CI-Logs, nicht an der ROADMAP. Letzter vollständiger
CI-Lauf: [42512193788](https://github.com/MagieGubi/Veyra-OS/actions/runs/42512193788),
alle 12 Jobs grün. Alle Laufzeitaussagen gelten nur für QEMU mit KVM.

Jedes Subsystem folgt demselben Schema: **Stand**, **Vorhanden**, **Fehlt**, **Probleme**,
**Abhängigkeiten**, **Sicherheitsrisiken**, **Nächste Schritte**, **Tests und Akzeptanz**.

---

## 1. Build-System und Toolchain

- **Stand:** funktioniert. Fünf Stufen (Host-Container, Cross-Toolchain, temporäre
  Werkzeuge, chroot-Bau, Abbild) laufen in `.github/workflows/toolchain.yml`. Stufen
  werden über Inhalts-Hashes (`build/scripts/stage-key.sh`) gecacht.
- **Vorhanden:** `toolchain/build-cross.sh` (GCC 15.2.0, glibc 2.42, C/C++),
  `temptools/`, `stage4/` (LFS 12.4 Kapitel 7/8), `build/scripts/fetch-sources.sh`,
  `check-pinned.sh` (jede Quelle per SHA-256 gepinnt), `vpkg-build`, `vpkg-verify`.
- **Fehlt:** lokaler Bau außerhalb von GitHub Actions ist dokumentiert
  (`docs/build-guide.md`), aber nicht regelmäßig geprüft; kein Build-Cache außerhalb
  von GitHub.
- **Probleme:** ein Bau ohne Cache dauert mehrere Stunden (Stufe 4b in drei Teilen);
  die Actions `upload-artifact@v4`, `download-artifact@v4`, `cache@v4` laufen noch auf
  Node.js 20 (Warnung in jedem Lauf).
- **Abhängigkeiten:** GitHub Actions (der Cloud-Rechner erreicht keine Spiegel),
  Debian-Container als Host.
- **Sicherheitsrisiken:** gering; Quellen werden vor dem Bau gegen gepinnte Hashes geprüft.
- **Nächste Schritte:** Actions auf Node-24-Versionen heben (ROADMAP P1-5).
- **Tests und Akzeptanz:** `check-pinned.sh` meldet 0 offene Quellen; CI grün.

## 2. Kernel

- **Stand:** funktioniert, reproduzierbar. Linux 6.18.56, Revision `veyra2`.
- **Vorhanden:** `x86_64_defconfig` plus Fragmente `kernel/config/veyra-*.config`
  (EFI-Stub mit eingebauter Kommandozeile, systemd-Anforderungen, Laptop-Treiber, Live).
  Zwei unabhängige Builds im CI, Prüfsummen verglichen.
- **Fehlt:** AMD-Grafik, Bluetooth, Sensoren: in den Veyra-Fragmenten nicht gesetzt; ob
  `x86_64_defconfig` sie mitbringt, ist nicht geprüft. Keine Modulsignatur
  (`MODULE_SIG=n`), kein Secure Boot.
- **Probleme:** die eingebaute Kommandozeile (`root=PARTLABEL=veyra-root`) macht den Kernel
  von genau einem Partitionsnamen abhängig; ein Installer braucht einen anderen Weg
  (Bootloader-Eintrag oder UKI mit eigener Kommandozeile).
- **Abhängigkeiten:** Cross-Toolchain.
- **Sicherheitsrisiken:** ohne Modulsignatur kann root beliebige Module laden.
- **Nächste Schritte:** Kommandozeile für installierte Systeme lösen (zusammen mit
  Bootloader, ROADMAP P3-3); Hardware-Fragmente nach dem ersten Hardware-Test ergänzen.
- **Tests und Akzeptanz:** Job „Kernel reproduzierbar?“ grün; Boot-Tests grün.

## 3. Basissystem (Stufe 4)

- **Stand:** funktioniert. 68 Pakete von glibc bis e2fsprogs, systemd 257.8.
- **Vorhanden:** Rezepte unter `packages/core/`, Bau im chroot, jedes Paket als `.vpkg`.
- **Fehlt:** Linux-PAM, sudo, nftables, iwd, Firmware, Bootloader, Werkzeuge für Btrfs.
  systemd ist mit `-D pam=disabled -D firstboot=false -D homed=disabled -D ukify=disabled`
  gebaut.
- **Probleme:** Reproduzierbarkeit der Basispakete ist Ziel, aber ungeprüft (P1-4).
- **Abhängigkeiten:** Toolchain, temporäre Werkzeuge.
- **Sicherheitsrisiken:** jede Sicherheitslücke muss Veyra selbst nachbauen; es gibt noch
  keinen Prozess für Sicherheitsupdates.
- **Nächste Schritte:** fehlende Pakete erst, wenn eine Aufgabe sie braucht (Installer:
  dosfstools/sfdisk prüfen; WLAN: iwd).
- **Tests und Akzeptanz:** `vpkg check` im gebooteten System: 73 Pakete, 0 Fehler.

## 4. VPKG

- **Stand:** Version 0.3, funktioniert für Installieren, Aktualisieren, Entfernen.
- **Vorhanden:** Befehle `install`, `upgrade`, `remove`, `list`, `info`, `files`,
  `owner`, `check`, `register`, `recover`, `index`. Abhängigkeiten und `provides` nach
  Namen, `conflicts`, Dateikonflikte, Konfigurationsdateien (`.vpkgnew`/`.vpkgsave`),
  Transaktionen mit Journal und Rücknahme, Absturz-Wiederherstellung, Ed25519-Signaturen
  für Pakete und Repository-Index, Stand- und Downgrade-Schutz, strenge Manifestprüfung.
- **Fehlt:** Versionsbedingungen in `depends` (`name>=ver`), Paketgruppen und Metapakete,
  Download über HTTPS, Mirrors, Paket-Cache, Rollback eines ganzen Updates, `pre_remove`.
- **Probleme:** Install-Skripte laufen nach dem Abschluss und sind nicht rücknehmbar.
  Ein `install`-Lauf aktualisiert keine Pakete, die eine zu alte Abhängigkeit haben,
  weil VPKG Versionen in Abhängigkeiten nicht kennt.
- **Abhängigkeiten:** Python 3 (nur Standardbibliothek), openssl, zstd, tar.
- **Sicherheitsrisiken:** kein Ablaufdatum im Index (ein Spiegel kann neue Stände
  zurückhalten); Install-Skripte laufen als root.
- **Nächste Schritte:** Versionsbedingungen (P1-3), danach Metapakete, HTTPS-Quellen.
- **Tests und Akzeptanz:** `tests/vpkg/vpkg-test.sh` (24 als root, 25 ohne root),
  `tests/vpkg/run.sh` (6), Selbsttest prüft Rücknahme und Signaturen im System.

## 5. Paket-Repository

- **Stand:** teilweise. Jeder CI-Lauf baut ein signiertes Repository (`veyra-repo`) mit
  Index-Stand = Commit-Zeit und installiert zur Gegenprobe ein Paket daraus.
- **Fehlt:** dauerhafte Veröffentlichung (Artefakte verfallen nach 7 Tagen), HTTPS-Abruf
  in VPKG, Mirror-Liste.
- **Probleme:** Artefaktspeicher von GitHub ist begrenzt (im Oktober voll, Lauf brach ab).
- **Abhängigkeiten:** Signaturschlüssel als Secret `VPKG_SIGNING_KEY` (nur bei Adrian).
- **Sicherheitsrisiken:** der private Schlüssel liegt nur als GitHub-Secret vor; er wird
  im Workflow mit Rechten 600 in eine temporäre Datei geschrieben und sofort gelöscht.
- **Nächste Schritte:** Veröffentlichung über GitHub Pages oder Releases (P3-1),
  dann `vpkg upgrade` im Selbsttest gegen das Online-Repository.
- **Tests und Akzeptanz:** CI-Ausgabe „Index signiert: ja“, Gegenprobe-Installation.

## 6. Boot und Abbild

- **Stand:** funktioniert in QEMU. GPT mit ESP (Kernel als `\EFI\BOOT\BOOTX64.EFI`),
  ext4-Root (`PARTLABEL=veyra-root`), FAT-Datenpartition für Messwerte.
- **Vorhanden:** `image/build-image.sh` (feste UUIDs, `SOURCE_DATE_EPOCH`),
  `image/boot-test.sh` (OVMF, Login, Selbsttest, Herunterfahren per ACPI),
  `image/boot-diagnose.sh`. Neu: Variante `dev` und `test` (siehe Abschnitt 8).
- **Fehlt:** Bootloader, mehrere Kernel, UKI, Secure Boot, Initramfs für installierte
  Systeme (nicht nötig, solange alle Treiber fest eingebaut sind).
- **Probleme:** Kernel-Update heißt heute: neue `BOOTX64.EFI` von Hand kopieren, ohne
  Rückfallmöglichkeit.
- **Abhängigkeiten:** Kernel, Basissystem.
- **Sicherheitsrisiken:** Secure Boot muss für echte Rechner aus.
- **Nächste Schritte:** Bootweg für installierte Systeme (P3-3 nach P3-2).
- **Tests und Akzeptanz:** Boot-Test grün (Login, Selbsttest OK, sauberes Herunterfahren).

## 7. Live-ISO

- **Stand:** funktioniert in QEMU (virtuelle SATA-CD). Eigenes statisches Init
  (`kernel/live/init.c`), SquashFS, tmpfs-Overlay.
- **Fehlt:** Installer auf der ISO, Rettungswerkzeuge, Bestätigung in VirtualBox.
- **Probleme:** die ISO entsteht aus dem Entwicklungsabbild: root ohne Passwort (bei
  Live-Systemen üblich, weil nichts dauerhaft gespeichert wird; dokumentiert).
- **Sicherheitsrisiken:** keine offenen Ports (geprüft), daher nur lokal erreichbar.
- **Nächste Schritte:** Installer aufnehmen, sobald es ihn gibt (P3-2).
- **Tests und Akzeptanz:** Boot-Test von CD grün.

## 8. Konten, Rechte und Sicherheit

- **Stand vor dieser Iteration:** jedes Abbild, auch der USB-Stick für echte Hardware,
  erlaubte die Anmeldung als root ohne Passwort; es gab keine Trennung zwischen
  Entwicklungs- und Testabbild und keine Prüfung von Konten und Rechten.
- **Neu in dieser Iteration (P0-3):**
  - `VARIANTE=dev|test` in `image/build-image.sh`; Variante in `/etc/veyra/variante`
    und `/etc/issue`.
  - Testabbild: root gesperrt (`!*`), `SU_WHEEL_ONLY yes`, Paket `veyra-konten` Pflicht.
  - `veyra-einrichtung` (Paket `veyra-konten`): fragt an Konsole 1 das root-Passwort
    (mindestens 8 Zeichen, zweimal) und optional einen Benutzer (Gruppe `wheel`) ab,
    schreibt erst nach vollständiger Eingabe, Passwörter nie auf der Kommandozeile.
  - `veyra-kontencheck`: Rechte von passwd/group/shadow, nur root mit UID 0, keine leeren
    Passwörter (im Testabbild gar keine, im Entwicklungsabbild nur root), keine für alle
    beschreibbaren Dateien; im Selbsttest beider Varianten.
- **Fehlt:** Linux-PAM, sudo, Passwortrichtlinien über die Mindestlänge hinaus,
  Sperre nach Fehlversuchen.
- **Probleme:** Hashes sind SHA-512-crypt (`openssl passwd -6`), nicht yescrypt, weil es
  dafür im Basissystem kein Kommandozeilenwerkzeug gibt.
- **Abhängigkeiten:** shadow, openssl, systemd.
- **Sicherheitsrisiken:** Entwicklungsabbild und Live-ISO bleiben ohne root-Passwort;
  beide sind als solche gekennzeichnet und nicht für echte Rechner gedacht.
- **Nächste Schritte:** CI-Boot des Testabbilds; PAM und sudo bewerten (PAM ist für
  einen grafischen Login-Manager ohnehin nötig).
- **Tests und Akzeptanz:** `tests/konten/konten-test.sh` (17), `tests/image/variante-test.sh`
  (4), Selbsttest „Konten und Rechte: ok“ in beiden Abbildern.

## 9. Netzwerk und Systemdienste

- **Stand:** Kabel funktioniert in QEMU (systemd-networkd mit DHCP, systemd-resolved),
  LLMNR und mDNS aus, außer Loopback keine offenen Ports.
- **Fehlt:** WLAN (Firmware, iwd), Bluetooth, Audio (PipeWire), Firewall (nftables),
  Drucker, Energieverwaltung, Suspend. Zeitsynchronisierung: systemd-timesyncd ist
  Standardteil von systemd; ob es im Abbild aktiv ist, ist nicht geprüft.
- **Probleme:** nur mit der QEMU-Karte e1000e getestet.
- **Abhängigkeiten:** systemd, Kernel-Treiber, Firmware.
- **Sicherheitsrisiken:** ohne Firewall schützt nur, dass kein Dienst lauscht.
- **Nächste Schritte:** Firmware-Paket (P2-3), dann WLAN (P2-4).
- **Tests und Akzeptanz:** Selbsttest „Netzwerk: ok“, „Offene Ports: ok“.

## 10. Hardware

- **Stand:** vorbereitet, nie getestet. Kompatibilitätsmatrix in
  [hardware-test.md](hardware-test.md).
- **Vorhanden:** NVMe, xHCI, USB-Massenspeicher/UAS, Intel-Grafik (i915), simpledrm,
  i8042-Tastatur, USB-HID, Touchpad (I2C-HID als Modul), Intel-WLAN-Treiber als Modul.
- **Fehlt:** Firmware, AMD-Grafik, Bluetooth, Sensoren, Audio-Prüfung, NVIDIA (bewusst aus).
- **Abhängigkeiten:** Adrians Laptop (MSI Katana 15) für den ersten Test.
- **Sicherheitsrisiken:** der Hardware-Test schreibt nur auf den USB-Stick; die interne
  SSD wird nur gelesen. Ab dieser Iteration ist das Hardware-Abbild das Testabbild.
- **Nächste Schritte:** erster Start vom USB-Stick (P2-2).
- **Tests und Akzeptanz:** `veyra-messung.txt` vom Stick mit „VEYRA-SELBSTTEST: OK“.

## 11. Installer, Updates, Recovery

- **Stand:** fehlt. Es gibt keinen Weg, Veyra auf eine Festplatte zu bringen, außer das
  ganze Abbild per `dd` zu schreiben.
- **Fehlt:** Installer (CLI), Partitionierung, Erkennung vorhandener Systeme,
  Kernel-Updates, System-Rollback, Rettungsablauf.
- **Abhängigkeiten:** Bootweg ohne festen Partitionsnamen, VPKG mit Versionsbedingungen.
- **Sicherheitsrisiken:** höchstes Risiko für Benutzerdaten; Tests nur mit virtuellen
  Platten, destruktive Schritte nur nach ausdrücklicher Bestätigung.
- **Nächste Schritte:** CLI-Installer (P3-2), Installationslogik getrennt von der
  Oberfläche, Test in QEMU mit leerer virtueller Platte.
- **Tests und Akzeptanz:** installierte virtuelle Platte bootet bis „Selbsttest OK“.

## 12. Grafische Oberfläche

- **Stand:** fehlt. Weder Mesa noch Wayland noch ein Compositor sind gebaut.
- **Abhängigkeiten:** Installer und stabile Updates zuerst; dann Grafikstapel aus Quellen.
- **Nächste Schritte:** erst nach Phase 3 und 4 (siehe DEVELOPMENT_PLAN.md).

## 13. CI und Qualitätssicherung

- **Stand:** funktioniert. Prüfungen: shellcheck, Rezept-Syntax, gepinnte Quellen,
  VPKG-Tests, Boot-Diagnose-Tests, Konten- und Abbild-Tests (neu), Kernel doppelt gebaut,
  Boot-Test von Platte und CD mit Selbsttest und Herunterfahren; neu: Boot des Testabbilds.
- **Probleme:** ein Push auf `main` bricht den laufenden Bau ab; der Artefaktspeicher ist
  begrenzt (Aufbewahrung inzwischen 1 Tag für Zwischenstände, 7 Tage für Abbilder;
  manueller Workflow „Artefakte aufraeumen“).
- **Nächste Schritte:** Reproduzierbarkeit der Pakete prüfen (P1-4).
