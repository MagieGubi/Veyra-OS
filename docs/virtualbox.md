# Veyra in VirtualBox

Zwei Wege, beide ohne Installation auf dem Rechner:

- **Live-ISO** `veyra-0.6-live.iso` (Artefakt `veyra-live-iso`): als CD einlegen,
  das System läuft im Arbeitsspeicher, Änderungen gehen beim Ausschalten verloren.
- **Festplatte** `veyra-0.6.vdi` (Artefakt `veyra-virtualbox`): Änderungen bleiben.

Beide Artefakte gibt es bei jedem grünen CI-Lauf, sie werden 7 Tage aufbewahrt.

## Live-ISO

1. Artefakt `veyra-live-iso` herunterladen und entpacken.
2. VirtualBox: **Neu**
   - Name `Veyra`, ISO-Abbild: `veyra-0.6-live.iso`, Typ **Linux**,
     Version **Other Linux (64-bit)**, unbeaufsichtigte Installation **überspringen**
   - Arbeitsspeicher mindestens 2048 MB, 2 CPUs, **EFI aktivieren**
   - Keine Festplatte nötig
3. Starten. Nach ein paar Sekunden erscheint `veyra login:`, anmelden als `root` ohne
   Passwort.

## Festplatte (VDI)

1. Artefakt `veyra-virtualbox` herunterladen und entpacken.
2. VirtualBox: **Neu**
   - Name `Veyra`, Typ **Linux**, Version **Other Linux (64-bit)**
   - Arbeitsspeicher 2048 MB, 2 CPUs
   - **EFI aktivieren** (Veyra startet ohne Bootloader direkt über UEFI)
   - Festplatte: **Vorhandene virtuelle Festplatte verwenden**, `veyra-0.6.vdi` wählen
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
- Netzwerk: Mit dem voreingestellten VirtualBox-Adapter (NAT) holt sich Veyra per DHCP
  eine Adresse und kommt ins Internet; prüfen mit `ip addr` und
  `getent hosts github.com`. In QEMU ist das im CI getestet, in VirtualBox noch nicht.
