# Bluetooth (Veyra 0.7)

Installieren: `vpkg install @veyra-bluetooth` (BlueZ 5.87, `veyra-bluetooth`). Firmware für
Intel-Chips: `vpkg install veyra-firmware-intel-bluetooth` (`veyra-hwinfo firmware` sagt, ob
sie gebraucht wird).

## veyra-bluetooth

```
veyra-bluetooth [status]             Dienst, Controller, Funksperre, Zahl der Geräte
veyra-bluetooth an | aus
veyra-bluetooth suche [--sekunden N] Geräte in der Nähe (Gerät in den Kopplungsmodus bringen)
veyra-bluetooth geraete [--json]     bekannte Geräte: gekoppelt, verbunden, vertraut
veyra-bluetooth koppeln ADRESSE      sicher koppeln, vertrauen, verbinden
veyra-bluetooth verbinde | trenne | entferne ADRESSE
veyra-bluetooth diagnose             für Fehlerberichte, Geräteadressen unkenntlich
```

`koppeln` nutzt den Agenten `KeyboardDisplay`: Zeigt das Gerät einen Code, fragt
bluetoothctl nach der Bestätigung; verlangt es eine PIN, wird sie abgefragt. Gekoppelte Geräte
werden als vertraut markiert und verbinden sich danach von selbst.
`--ohne-rueckfrage` (für Skripte) erlaubt nur Geräte ohne Anzeige und Tastatur ("Just Works").

## Rechte

BlueZ erlaubt den Zugriff über D-Bus normalerweise nur in einer Konsolensitzung (`at_console`),
die es ohne PAM nicht gibt. `veyra-bluetooth` bringt deshalb eine Regel mit: Zugriff hat
root, die **Gruppe `bluetooth`** (`usermod -aG bluetooth NAME`) und der Tondienst `pipewire`
(für Bluetooth-Kopfhörer über WirePlumber).

## Was geprüft ist

| Prüfung | Wo | Ergebnis |
| --- | --- | --- |
| zwei virtuelle Controller (`hci_vhci`, BlueZ-Emulator `btvirt`), suchen, koppeln, verbinden, trennen, entfernen | QEMU (CI, `image/bluetooth-test.py`) | siehe CI |
| Kopplung übersteht Neustart von bluetoothd | QEMU | siehe CI |
| Gruppe `bluetooth` darf, andere Benutzer nicht | QEMU | siehe CI |
| echter Chip mit Firmware, Kopfhörer (A2DP), Maus/Tastatur (HID) | echte Hardware | **offen** |
