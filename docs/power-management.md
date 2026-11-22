# Energieverwaltung (Veyra 0.7)

Installieren: `vpkg install veyra-power` (in `@veyra-laptop` enthalten).

## veyra-power

```
veyra-power [status] [--json]    Netzteil, Akku (Ladung, Restzeit, Abnutzung, Ladezyklen),
                                 CPU-Regler und Energievorgabe, Plattform-Profil,
                                 Ruhezustände, Verhalten bei Deckel und Einschalttaste
veyra-power profil [NAME]        auto | energiesparen | ausgewogen | leistung
veyra-power schlafen [--wecken SEKUNDEN] [--art s2idle|deep]
veyra-power diagnose
```

### Profile

| Profil | CPU-Regler | Energievorgabe (EPP) | Plattform-Profil |
| --- | --- | --- | --- |
| energiesparen | powersave | power | low-power / quiet |
| ausgewogen | schedutil, sonst powersave | balance_performance | balanced |
| leistung | performance | (bleibt, gilt nur mit powersave) | performance |
| **auto** (Standard) | am Netzteil wie *ausgewogen*, im Akkubetrieb wie *energiesparen* | | |

Genommen wird jeweils der erste Wert, den die Hardware anbietet. Bei Intel-CPUs mit
`intel_pstate` gibt es nur die Regler `powersave` und `performance`; die eigentliche Steuerung
läuft dort über die Energievorgabe. Das Profil steht in `/etc/veyra/power.conf`;
`veyra-power.service` wendet es beim Start an, eine udev-Regel bei jedem Ein- oder Ausstecken
des Netzteils.

### Ruhezustand

- `s2idle`: Standby im Betriebssystem. Neuere Laptops (auch Intel Core 12. bis 14. Generation)
  bieten oft nur diesen an.
- `deep` (S3, Suspend-to-RAM): klassischer Ruhezustand, wenn die Firmware ihn anbietet.

`/sys/power/mem_sleep` zeigt, welche es gibt; der Eintrag in Klammern ist der Standard.
Deckel zu: Ruhezustand (auch am Netzteil), angedockt: nichts
(`/usr/lib/systemd/logind.conf.d/50-veyra-power.conf`, eigene Werte nach
`/etc/systemd/logind.conf.d/`). Ruhezustand auf Festplatte (Hibernate) gibt es noch nicht,
weil Veyra keinen Swap anlegt.

## Was geprüft ist

| Prüfung | Wo | Ergebnis |
| --- | --- | --- |
| Profile, Akku-Berechnung, Netzteilwechsel, Seriennummern verborgen | Einzeltests (`tests/power`) | grün |
| Ruhezustand S3 (deep): einschlafen, von der Echtzeituhr geweckt, Dienste laufen weiter | QEMU (CI, `image/power-test.py`) | [bestanden](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995) |
| Ruhezustand s2idle: einschlafen und weiterarbeiten | QEMU | [bestanden](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995), aber in QEMU weckt die Echtzeituhr s2idle nicht; der Test weckt dann mit der Ein-Taste (QEMU-Monitor) und sagt das. RTC-Wecken aus s2idle ist nur auf Hardware prüfbar |
| Profil nach Neustart angewendet | QEMU | [bestanden](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995) |
| Akku, Netzteil, Deckel, intel_pstate, Ruhezustand am Laptop | echte Hardware | **offen** |
