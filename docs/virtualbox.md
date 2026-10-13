# Veyra in VirtualBox

Veyra Core 0.1 gibt es als fertige VirtualBox-Festplatte `veyra-core-0.1.vdi`
(Artefakt `veyra-virtualbox` jedes grünen CI-Laufs, 14 Tage aufbewahrt). Es wird nichts
installiert: das ganze System liegt in dieser Datei.

## Einrichten

1. Artefakt `veyra-virtualbox` herunterladen und entpacken.
2. VirtualBox: **Neu**
   - Name `Veyra`, Typ **Linux**, Version **Other Linux (64-bit)**
   - Arbeitsspeicher 2048 MB, 2 CPUs
   - **EFI aktivieren** (Veyra startet ohne Bootloader direkt über UEFI)
   - Festplatte: **Vorhandene virtuelle Festplatte verwenden**, `veyra-core-0.1.vdi` wählen
3. In den Einstellungen der VM unter **Massenspeicher** prüfen, dass die Platte an einem
   **SATA**-Controller hängt (nicht IDE). Unter **Anzeige** den Grafikcontroller
   **VMSVGA** lassen.
4. Starten. Nach ein paar Sekunden erscheint `veyra login:`. Anmelden als `root`
   ohne Passwort (Entwicklungsabbild).

Etwa 20 s nach dem Start läuft der Selbsttest und zeigt sein Ergebnis auf dem Bildschirm
(`VEYRA-SELBSTTEST: OK`) mit den Messwerten. Ausschalten mit `poweroff`.

## Hinweise

- Ist unter Windows Hyper-V oder die virtualisierungsbasierte Sicherheit aktiv, läuft
  VirtualBox langsamer. Die Bootzeit in VirtualBox ist deshalb kein Messwert für Veyra.
- Bisher gibt es nur die Textkonsole, keine grafische Oberfläche.
- Das Netzwerk (Intel-Netzwerkkarte von VirtualBox) wird erkannt, ist aber noch nicht
  eingerichtet.
