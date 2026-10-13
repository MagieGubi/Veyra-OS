# Phase 6: Bestandsaufnahme und VPKG-Transaktionen

Phase 6 heißt Hardware-Kompatibilität, Systemstabilität und Release 0.2. Dieser erste
Schritt behebt einen echten Fehler in VPKG, bevor neue Funktionen dazukommen.

## Ausgangszustand (vor dieser Änderung)

| Bereich | Stand | Nachweis |
| --- | --- | --- |
| Cross-Toolchain, temporäre Werkzeuge, Basissystem (68 Pakete) | implementiert | CI grün |
| Kernel 6.18.56-veyra2 mit Laptop-Treibern (NVMe, Intel-Grafik, Tastatur, Touchpad) | implementiert, auf echter Hardware **nicht** getestet | CI grün, zwei Builds bit-identisch |
| Abbild, UEFI-Boot ohne Bootloader bis zum Login | implementiert | QEMU mit KVM im CI |
| Live-ISO mit eigenem Init (SquashFS + Overlay im RAM) | implementiert | QEMU im CI, von virtueller SATA-CD |
| VirtualBox-Festplatte (VDI) | gebaut | in VirtualBox noch nicht bestätigt |
| VPKG: installieren, entfernen, Abhängigkeiten, Signaturen | implementiert | 15 + 6 Tests lokal grün, Selbsttest im Abbild |
| VPKG: abgebrochener Vorgang | **fehlerhaft** | siehe unten |
| Netzwerk | Netzwerkkarte wird erkannt, aber nicht eingerichtet (keine DHCP-Konfiguration) | Bootlog im CI |
| Firmware (WLAN, Intel-Grafik-DMC) | fehlt | kein Firmware-Paket |
| Echte Hardware | nur vorbereitet (USB-Stick-Abbild, [hardware-test.md](hardware-test.md)) | noch nicht getestet |

Lokal ausgeführt (Python 3.13): `bash tests/vpkg/vpkg-test.sh` → 15 von 15 bestanden,
`bash tests/vpkg/run.sh` → 6 von 6 bestanden.

### Gefundener Fehler

VPKG 0.1 schrieb Dateien direkt ins System und trug das Paket erst am Ende ein. Scheiterte
ein Schreibvorgang (fehlende Rechte, volle Platte, Abbruch), passierte Folgendes:

1. Python-Traceback statt Fehlermeldung.
2. Bereits kopierte Dateien blieben liegen, gehörten aber keinem Paket.
3. `vpkg check` meldete nichts, weil es nur eingetragene Pakete prüft.
4. Eine erneute Installation scheiterte am Dateikonflikt mit den eigenen Resten.

Nachgestellt als normaler Benutzer mit schreibgeschütztem `/usr/lib` im Zielsystem: Nach
dem Abbruch lag `/usr/bin/eins` im System, `vpkg list` war leer, `vpkg check` meldete
0 Fehler. Bei einem Update war es schlimmer: halb neue, halb alte Dateien, und die
Datenbank beschrieb noch die alte Version.

Außerdem führten fehlerhafte Werte im Manifest (z. B. `mode = "9999"`) zu einem
Python-Traceback statt zu einer klaren Ablehnung.

## Die fünf wichtigsten Verbesserungen

Bewertung: hoch, mittel, niedrig.

| # | Verbesserung | Nutzbarkeit | Sicherheit | Machbarkeit | Abhängigkeiten | Testbar in CI/QEMU |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **VPKG-Transaktionen**: Abbruch und Absturz nehmen alles zurück, Manifest wird streng geprüft | hoch (jedes Update, jede Installation) | hoch (manipulierte Manifeste, halbfertige Systeme) | hoch (nur VPKG) | keine | voll (Tests ohne root, Selbsttest im Abbild) |
| 2 | Netzwerk einrichten (systemd-networkd mit DHCP), Prüfung im Selbsttest | hoch | mittel (offene Dienste prüfen) | hoch | systemd vorhanden | voll (QEMU-Netz) |
| 3 | Dienste und Herunterfahren prüfen: `systemctl --failed` leer, `poweroff` sauber, im Boot-Test | mittel | niedrig | hoch | keine | voll |
| 4 | Repository-Index signieren, Schutz gegen ältere Versionen (Downgrade) | mittel | hoch | mittel | Signaturschlüssel im CI | voll |
| 5 | Firmware-Paket (Intel-Grafik-DMC, Intel-WLAN und Bluetooth) | hoch auf echter Hardware | niedrig | mittel (Lizenzen, Größe) | Kernel-Konfiguration | nur auf echter Hardware |

**Gewählt: Nummer 1.** Es ist ein nachgewiesener Fehler, kein fehlendes Extra. Jede
weitere Phase (Updates, Netzwerk-Repository, Desktops) installiert Pakete; ohne
Rücknahme kann jedes fehlgeschlagene Update das System unbrauchbar machen, und
`vpkg check` hätte es nicht einmal bemerkt. Die Änderung bleibt in einer Komponente,
ändert weder Kernel noch Toolchain noch Paketformat und lässt sich komplett ohne
Hardware testen.

## Was geändert wurde

VPKG 0.2 (`packages/base/vpkg/vpkg`):

- **Transaktionen** für `install`, `upgrade`, `remove` und `register`. Jede Änderung wird
  vorher in `/var/lib/vpkg/txn/journal` protokolliert (JSON-Zeile, `fsync`). Ersetzte und
  gelöschte Dateien kommen in eine Sicherung, neue Dateien werden über eine temporäre
  Datei und `rename` gesetzt. Bei einem Fehler nimmt VPKG alles in umgekehrter
  Reihenfolge zurück. Details: [vpkg.md](vpkg.md#transaktionen).
- **Absturz-Wiederherstellung**: Bleibt ein Journal liegen, meldet `vpkg check` das. Neuer
  Befehl `vpkg recover`; der nächste schreibende Befehl nimmt den Vorgang ebenfalls
  automatisch zurück.
- **Strenge Manifestprüfung** vor jeder Änderung: Typ, Rechte, Prüfsumme, Link-Ziel,
  Namen in Abhängigkeiten, keine doppelten Pfade, nichts unter `/var/lib/vpkg`, nichts
  unterhalb einer Datei oder eines Links, kein Nullbyte im Pfad.
- **Fehlermeldungen** statt Traceback bei Schreibfehlern.
- Neuer Datenbankeintrag wird im Transaktionsverzeichnis vorbereitet, nicht mehr als
  `installed/NAME.neu`. Ein Abbruch genau an dieser Stelle hinterließ sonst ein
  Scheinpaket `NAME.neu`; der neue Test 16 hat das gefunden.

## Geänderte Dateien

| Datei | Zweck |
| --- | --- |
| `packages/base/vpkg/vpkg` | Transaktionen, Wiederherstellung, Manifestprüfung, Fehlermeldungen; Version 0.2 |
| `packages/base/vpkg/recipe.sh` | Version 0.2, neue Prüfsumme des Programms |
| `tests/vpkg/vpkg-test.sh` | Tests 16 bis 20 (siehe unten) |
| `packages/test/veyra-selftest/recipe.sh` | Selbsttest im gebooteten System bricht eine Installation ab und prüft die Rücknahme (Version 0.3) |
| `.github/workflows/toolchain.yml` | nur der Name des VPKG-Testschritts |
| `docs/vpkg.md`, `README.md`, `docs/phase6.md` | Dokumentation |

## Tests

Neue Tests in `tests/vpkg/vpkg-test.sh`:

| Nr. | Prüft |
| --- | --- |
| 16 | Update `app` 1.0 → 2.0 mit geänderter Konfigurationsdatei, Abbruch nach 0, 1, 2, … Änderungen, bis das Update durchläuft. Nach jedem Abbruch muss der Dateibaum (Typ, Rechte, Inhalt) samt `vpkg list` identisch sein, kein Journal und keine temporäre Datei bleiben, `vpkg check` fehlerfrei sein und kein Traceback erscheinen. |
| 17 | Dasselbe für `vpkg remove`. |
| 18 | Simulierter Absturz (Prozess endet sofort): Journal bleibt, `vpkg check` meldet es, `vpkg recover` stellt den Zustand wieder her; nach einem zweiten Absturz nimmt die nächste Installation ihn selbst zurück und läuft dann durch. |
| 19 | Echter Schreibfehler (schreibgeschütztes Verzeichnis): Meldung `vpkg: Installation abgebrochen ...`, nichts bleibt liegen. Läuft nur ohne root (als root greifen die Rechte nicht); das CI läuft ohne root. |
| 20 | Sieben manipulierte Manifeste (Rechte `9999`, doppelter Pfad, Pfad in der Paketdatenbank, Pfad unter einer Datei, ungültige Prüfsumme, unbekannter Typ, Abhängigkeit `../etc`) werden ohne Traceback und ohne Änderung abgelehnt. |

Selbsttest im Abbild (CI-Jobs `image` und `live-iso`): `VPKG_TEST_ABBRUCH=fehler:1 vpkg
install vpkg-demo` muss scheitern, danach darf weder `/usr/bin/vpkg-demo` noch der
Eintrag noch `/var/lib/vpkg/txn` existieren, und `vpkg check` muss fehlerfrei sein.

### Ergebnisse (lokal, 2026-10-13, Python 3.13)

| Befehl | Ergebnis |
| --- | --- |
| `bash tests/vpkg/vpkg-test.sh` als root | 19 von 19 bestanden, Test 19 übersprungen (root) |
| `bash tests/vpkg/vpkg-test.sh` als Benutzer `nobody` | 20 von 20 bestanden |
| `bash tests/vpkg/run.sh` | 6 von 6 bestanden |
| Einmalige Zusatzprüfung: simulierter Absturz an **jeder** Stelle eines Updates (9 Änderungen) und eines Entfernens (12 Änderungen), danach `vpkg recover` | an allen 21 Stellen Zustand identisch, `vpkg check` fehlerfrei |
| Nachstellung des ursprünglichen Fehlers (schreibgeschütztes `/usr/lib`) | jetzt: `vpkg: Installation abgebrochen ([Errno 13] Permission denied ...); 2 Aenderung(en) zurueckgenommen, das System ist unveraendert`, `/usr/bin/eins` weg |

### Ergebnisse (CI)

Wird nach dem CI-Lauf eingetragen.

## Sicherheit

Behoben:

- Halbfertige Installationen und Updates, die `vpkg check` nicht sah.
- Manifeste mit ungültigen Werten, Pfaden in der Paketdatenbank oder Einträgen unter
  einem Link wurden nicht oder nur mit Traceback abgelehnt. Ein Eintrag unter einem Link
  aus demselben Paket hätte sonst als Umweg in fremde Verzeichnisse dienen können;
  `place()` prüfte das Zielverzeichnis zwar schon, jetzt wird so ein Paket aber vor
  jeder Änderung abgelehnt.

Offen:

- Install-Skripte (`post_install`) laufen als root und lassen sich nicht zurücknehmen.
- Der Repository-Index ist nicht signiert, und es gibt keinen Schutz gegen ältere
  Versionen (Verbesserung 4).
- Das Entwicklungsabbild hat root ohne Passwort.

## Einschränkungen

- Nichts davon wurde auf echter Hardware getestet, nur lokal und in QEMU.
- Der Absturz-Test simuliert das Ende des Prozesses (`os._exit`). Einen echten
  Stromausfall mit Schreibcache des Datenträgers deckt er nicht ab; dafür sorgen `fsync`
  auf Journal und Verzeichnis, geprüft ist das aber nicht.
- Ändert jemand während eines Vorgangs selbst Dateien im System, kann die Rücknahme
  scheitern. VPKG lässt das Journal dann stehen und nennt die betroffenen Pfade.

## Nächster Schritt

Verbesserung 2 und 3 zusammen: Netzwerk per systemd-networkd und DHCP einrichten und im
Boot-Test prüfen, dass keine Dienste fehlschlagen und `poweroff` sauber endet. Das ist
die Voraussetzung, um Pakete später aus einem Online-Repository zu installieren. Danach
folgt Verbesserung 4 (signierter Index), bevor das Repository öffentlich wird.
