# Hardware-Test für Veyra 0.7 (WLAN, Ton, Bluetooth, Energie)

Für Adrians Laptop (MSI Katana 15 B13VFK), passt aber für jeden Laptop. Dauer etwa 20 Minuten.
Windows und die interne SSD bleiben unverändert: Veyra läuft nur vom USB-Stick.

Die Release-Kriterien von 0.7 verlangen diesen Test; vorher wird 0.7 nicht als fertig gemeldet.

## Vorbereitung

1. Im letzten grünen CI-Lauf das Artefakt **`veyra-0.7-laptop-test`** herunterladen
   (GitHub, Reiter „Actions“, Lauf öffnen, unten „Artifacts“; braucht die GitHub-Anmeldung).
   Darin: `veyra-0.7-laptop-test.img.zst`, die Prüfsumme `SHA256SUMS-laptop-test` und diese
   Anleitung.
2. Entpacken (7-Zip kann `.zst`) und mit balenaEtcher oder Rufus im DD-Modus auf einen
   USB-Stick mit mindestens 8 GB schreiben. **Alles auf dem Stick wird gelöscht.** Fragt
   Windows danach, ob ein Laufwerk formatiert werden soll: Abbrechen.
3. Secure Boot im BIOS ausschalten (beim Start `Entf`, Reiter „Security“).
4. Stick einstecken, beim Start `F11`, den Stick wählen.
5. Erster Start: root-Passwort festlegen (zweimal), eigener Benutzer optional.
6. Für Bluetooth ein Gerät bereitlegen (Kopfhörer oder Maus), für WLAN das Passwort.
   Kopfhörer mit Kabel, falls vorhanden.

## Test

Als root anmelden und starten:

```
veyra-hardwaretest
```

Das Programm führt durch die Schritte und fragt, wo nur ein Mensch urteilen kann
(„Hast du den Ton gehört?“). Mit `s` lässt sich jeder Schritt überspringen.

| Schritt | Was passiert | Was du tust |
| --- | --- | --- |
| System | Hardware und Firmware erfassen | nichts |
| WLAN | Netze suchen, verbinden, Adresse und DNS prüfen | Netznamen eintippen, Passwort (iwctl fragt, es kommt nicht in den Bericht) |
| Ton | 3 s Pfeifton aus den Lautsprechern, optional Kopfhörerbuchse | sagen, ob du ihn gehört hast |
| Mikrofon | 4 s Aufnahme, Pegel messen | sprechen oder klatschen |
| Bluetooth | Suche 15 s, optional koppeln, Ton auf Bluetooth-Kopfhörer | Gerät in den Kopplungsmodus, Adresse abtippen |
| Akku | Netzteil ab- und wieder anstecken | Netzteil ziehen und einstecken |
| Ruhezustand | schläft 20 s und wacht selbst auf; dann Deckel zu und auf | Deckel schließen, 15 s warten, öffnen |
| Grafik | prüft, ob die Intel-Grafik ihre Firmware (DMC, GuC) geladen hat | nichts |

Danach `poweroff`, Windows starten und aus dem Laufwerk **VEYRA-DATEN** diese Dateien schicken:

- `veyra-hardwaretest.txt`: Ergebnis je Schritt (OK, FEHLER, ÜBERSPRUNGEN) und Einzelheiten
- `veyra-messung.txt` und `kernel-log.txt`: Selbsttest und Kernel-Meldungen

Passwörter, Seriennummern und Geräteadressen stehen in keiner der Dateien.

Einzelne Schritte wiederholen: `veyra-hardwaretest --nur ton,mikrofon`.

## Bekannte Grenzen

- NVIDIA-Grafik bleibt aus; das Bild kommt von der Intel-Grafik.
- Ist das eingebaute Mikrofon ein Digitalmikrofon am Audio-DSP (Intel SOF), bleibt es in 0.7
  stumm; das zeigt der Schritt „Mikrofon“, und genau dafür ist der Test da (docs/audio.md).
