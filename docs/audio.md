# Ton (Veyra 0.7)

Installieren: `vpkg install @veyra-audio` (Metapaket `veyra-audio`).

## Aufbau

| Teil | Version | Aufgabe |
| --- | --- | --- |
| Kernel | 6.18.56-veyra | HD-Audio (`snd_hda_intel`, Codecs von Realtek, Conexant, HDMI/DP als Module), USB-Audio |
| ALSA | alsa-lib 1.2.16.1, alsa-utils 1.2.16 | Schnittstelle zum Kernel; `aplay`, `arecord`, `alsamixer` |
| PipeWire | 1.6.6 | Tonserver; ALSA-Programme laufen über ihn (`/etc/alsa/conf.d/99-pipewire-default.conf`) |
| WirePlumber | 0.5.14 | Sitzungsverwaltung: Geräte, Standardgerät, Lautstärke, Bluetooth-Ton |
| pipewire-pulse | 1.6.6 | PulseAudio-Schnittstelle für Programme wie Firefox |
| veyra-audio | 0.7 | Werkzeug (unten) |

Veyra hat kein PAM und damit keine Benutzersitzungen von systemd. PipeWire, WirePlumber und
pipewire-pulse laufen deshalb als Systemdienste (`veyra-pipewire`, `veyra-wireplumber`,
`veyra-pipewire-pulse`) unter dem Benutzer `pipewire`, mit dem Socket `/run/pipewire/pipewire-0`.
**Ton bekommt, wer in der Gruppe `pipewire` ist:** `usermod -aG pipewire NAME`.
Das ist eine bewusste Vereinfachung für 0.7: alle Mitglieder der Gruppe teilen sich einen
Tonserver. Getrennte Sitzungen je Benutzer kommen mit einem Sitzungsverwalter (0.8, Desktop).

## veyra-audio

```
veyra-audio                      Status: Dienste, Standard-Ausgabe und -Eingabe
veyra-audio geraete [--json]     alle Ausgaben und Eingaben mit ID, Lautstärke, Bus
veyra-audio standard ID          Standardgerät setzen
veyra-audio lautstaerke [ausgabe|eingabe|ID] WERT    z. B. 40, +5, -5
veyra-audio stumm [ausgabe|eingabe|ID] [an|aus|um]
veyra-audio test [--sekunden N]  440-Hz-Testton auf der Standard-Ausgabe
veyra-audio aufnahme-test        nimmt kurz auf und zeigt den Pegel in dBFS
veyra-audio diagnose             alles für einen Fehlerbericht
```

## Was geprüft ist

| Prüfung | Wo | Ergebnis |
| --- | --- | --- |
| Dienste starten, WirePlumber meldet Ausgabe und Eingabe | QEMU (CI, `image/audio-test.py`) | [bestanden](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995) |
| Testton kommt an: QEMU schreibt den Ton als WAV-Datei, der Test misst Pegel und Frequenz | QEMU | [bestanden](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995) (4,2 s Signal, Spitze −10,2 dBFS) |
| ALSA-Programm (`aplay`) über PipeWire | QEMU | [bestanden](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995) |
| Aufnahmeweg (QEMU liefert Stille, nur der Weg wird geprüft) | QEMU | [bestanden](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995) |
| Nur Mitglieder von `pipewire` haben Ton | QEMU | [bestanden](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995) |
| Lautsprecher, Kopfhörerbuchse, eingebautes Mikrofon | echte Hardware | **offen** (docs/hardware-compatibility.md) |
| HDMI-Ton, USB-Headset, Bluetooth-Kopfhörer | echte Hardware | **offen** |

## Bekannte Grenzen

- **Intel SOF:** Neuere Intel-Laptops schließen eingebaute Digitalmikrofone über den
  Audio-DSP an; dafür braucht Linux den SOF-Treiber und Firmware von `sof-bin`. Veyra 0.7
  aktiviert SOF noch nicht: blind eingeschaltet würde SOF auf Rechnern ohne passende Firmware
  den ganzen Ton abschalten. Der Hardware-Test zeigt, ob das Mikrofon über HD-Audio läuft;
  wenn nicht, kommt SOF mit genau der Firmware, die der Rechner verlangt.
- Keine UCM-Profile (`alsa-ucm-conf`); für HD-Audio ohne DSP nicht nötig.
