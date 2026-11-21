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
| Ruhezustand s2idle und S3, Wecken über die Echtzeituhr, Dienste laufen danach weiter | QEMU (CI, `image/power-test.py`) | siehe CI |
| Profil nach Neustart angewendet | QEMU | siehe CI |
| Akku, Netzteil, Deckel, intel_pstate, Ruhezustand am Laptop | echte Hardware | **offen** |
