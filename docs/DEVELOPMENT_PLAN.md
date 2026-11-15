# Veyra OS: Entwicklungsplan

Stand: 15.11.2026. Grundlage: [FULL_SYSTEM_AUDIT.md](FULL_SYSTEM_AUDIT.md). Einzelne Aufgaben
mit Dateien, Schritten, Risiken, Akzeptanzkriterien und Nachweis stehen in
[../ROADMAP.md](../ROADMAP.md); dieser Plan ordnet sie den sieben Phasen der Spezifikation
„Full Operating System Development Mission“ zu.

Grundsätze: alles aus Quellcode, gepinnte Quellen, kleine Schritte, jede Aufgabe erst
fertig mit grünem CI-Nachweis. Destruktive Schritte (Partitionieren, Formatieren) nur auf
virtuellen Platten im Test und nur nach ausdrücklicher Bestätigung.

## Die drei wichtigsten offenen Aufgaben

Ausgewählt danach, was Veyra am stärksten zu einem installierbaren, alltagstauglichen
System bringt, und in der Reihenfolge der Abhängigkeiten:

1. **Sichere Root-Konfiguration, Entwicklungs- und Testabbild trennen (P0-3).**
   Blocker für jeden Test auf echter Hardware: bisher konnte sich jeder am USB-Stick als
   root ohne Passwort anmelden. Der Installer braucht dieselbe Ersteinrichtung (Passwort,
   erster Benutzer). **Erledigt** (CI-Lauf 43653042098).
2. **Versionsbedingungen in VPKG (P1-3).** Ohne `name>=version` kann VPKG weder Updates
   in sicherer Reihenfolge noch einen Installer mit konsistenten Paketständen liefern.
   Klein, gut testbar, keine Hardware nötig. **Erledigt** (CI-Lauf 43753648158).
3. **CLI-Installer auf eine virtuelle Platte (P3-2).** Der größte Schritt zu „installierbar“:
   Ziel nur nach ausdrücklicher Auswahl und Bestätigung, GPT mit ESP und ext4, Basispakete
   über VPKG, Ersteinrichtung aus Aufgabe 1. Test in QEMU mit leerer virtueller Platte.
   **Umgesetzt** mit dem vorhandenen Bootweg (Kernel direkt, `PARTLABEL=veyra-root`;
   der Installer lehnt ab, wenn schon eine zweite Partition `veyra-root` existiert).
   Lokal getestet, CI-Nachweis steht aus.

## Phase 1: Systemstabilität und Sicherheit (kritisch)

| Aufgabe | ROADMAP | Stand |
| --- | --- | --- |
| Signierter Repository-Index, Downgrade-Schutz | P0-1 | ✅ |
| Keine offenen Ports | P0-2 | ✅ |
| Sichere Root-Konfiguration, Dev/Test getrennt, Ersteinrichtung, Kontenprüfung | P0-3 | ✅ |
| Transaktionen, Absturz-Wiederherstellung, Manifestprüfung | P1-1, P1-2 | ✅ |
| Versionsbedingungen | P1-3 | ✅ |
| Reproduzierbarkeit von Paketen und Abbild | P1-4 | ⬜ |
| `pre_remove`, fehlgeschlagene Install-Skripte | P1-6 | ⬜ |
| PAM und sudo bewerten (für Login-Manager nötig) | P1-8 | ⬜ |

## Phase 2: Hardware (hoch)

Erst messen, dann bauen: P2-2 (erster Start auf Adrians Laptop) liefert das Kernel-Log,
nach dem Treiber ergänzt werden. Firmware (P2-3) mit Lizenzdateien aus dem gepinnten
linux-firmware-Archiv, dann WLAN (P2-4). AMD-Grafik, Bluetooth, Sensoren und Audio erst,
wenn dafür Testhardware verfügbar ist. Matrix: [hardware-test.md](hardware-test.md).

## Phase 3: Bootsystem und Installation (kritisch)

1. Bootweg für installierte Systeme: Kernel-Kommandozeile nicht mehr fest eingebaut
   (UKI oder systemd-boot prüfen; ob das systemd-Paket systemd-boot baut, ist offen).
2. CLI-Installer (P3-2) mit getrennter Logik (`veyra-install`-Bibliothek) und Oberfläche:
   Datenträger auflisten, vorhandene Systeme erkennen (Partitionstabellen, Dateisysteme),
   Ziel nur nach Eingabe des Gerätenamens bestätigen, automatische Partitionierung zuerst.
3. Kernel-Updates mit Rückfall auf den vorigen Kernel, Recovery-Ablauf (P3-4), Btrfs
   als Option erst danach.

## Phase 4: VPKG und Paket-Repository (kritisch)

Versionsbedingungen (P1-3), Metapakete und Gruppen, Abruf über HTTPS mit Mirror-Liste
und Cache, dauerhaftes Online-Repository (P3-1), Veröffentlichungsablauf
(bauen, signieren mit dem Secret, Index-Stand erhöhen, hochladen). Private Schlüssel
bleiben im GitHub-Secret.

## Phase 5: Netzwerk und Systemdienste

WLAN mit WPA2/WPA3 (iwd), Zeitsynchronisierung prüfen und einschalten, nftables-Firewall
mit „alles eingehend zu“, Journal-Größe begrenzen, später Audio (PipeWire), Bluetooth
(BlueZ), Drucker (CUPS), Energieverwaltung. Jeder Dienst bekommt eine Prüfung im Selbsttest.

## Phase 6: Grafische Oberfläche

Erst wenn Installation und Updates stabil sind. Reihenfolge: libdrm, Mesa, Wayland,
ein kleiner Compositor, PipeWire, kitty; danach Login-Manager (braucht PAM), Panel,
Einstellungen. Veyra-eigene Teile als eigene VPKG-Pakete.

## Phase 7: Release 1.0

Veyra gilt als 1.0, wenn alle folgenden Punkte mit Nachweis erfüllt sind:

- Installations-ISO bootet auf mindestens drei dokumentierten echten Rechnern und in
  QEMU und VirtualBox.
- Installation auf NVMe und SATA mit automatischer Partitionierung; vorhandene Systeme
  werden erkannt und nie ohne Bestätigung überschrieben.
- Ersteinrichtung mit eigenem Benutzer, root nicht ohne Passwort erreichbar.
- Ethernet und WLAN, Updates über ein dauerhaftes, signiertes Online-Repository,
  Kernel-Update mit Rückfall, dokumentierter Rettungsablauf.
- Grafischer Desktop mit Audio auf mindestens einem echten Rechner.
- CI: alle Regressionstests grün, Pakete und Abbild reproduzierbar.
- Anleitungen für Anwender (Installation, Rettung) und Entwickler (Bau, Pakete).

## Arbeitsweise je Iteration

Analyse, eine Aufgabe vollständig umsetzen, lokale Tests, Commit und Push nur mit Adrians
ausdrücklicher Erlaubnis, CI-Nachweis, ROADMAP und SYSTEM_STATUS aktualisieren, Bericht.
