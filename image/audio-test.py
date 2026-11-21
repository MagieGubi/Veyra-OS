#!/usr/bin/env python3
"""Ton (Veyra 0.7) in QEMU: startet das Entwicklungsabbild mit einer HD-Audio-Karte
(ich9-intel-hda mit hda-duplex). QEMU schreibt alles, was der Gast abspielt, in eine WAV-Datei
auf dem Wirt. Auf der Platte ist zusaetzlich @veyra-audio installiert (PipeWire, WirePlumber,
pipewire-pulse als Systemdienste, veyra-audio).

Geprueft wird:
  - die Dienste veyra-pipewire, veyra-wireplumber und veyra-pipewire-pulse laufen
  - der Kernel erkennt die Karte, WirePlumber meldet eine Ausgabe und eine Eingabe (PCI)
  - ein Benutzer der Gruppe pipewire (nicht root) sieht die Geraete
  - "veyra-audio test" spielt einen 440-Hz-Ton; in der WAV-Datei auf dem Wirt steht ein
    Signal mit Pegel und Frequenz des Tons (das ist der eigentliche Nachweis)
  - ALSA-Programme laufen ueber PipeWire (aplay auf das Standardgeraet)
  - "veyra-audio aufnahme-test" nimmt von der Eingabe auf (QEMU liefert Stille; geprueft
    wird der Aufnahmeweg, nicht der Pegel)
  - Lautstaerke setzen und stummschalten

Aufruf: image/audio-test.py PLATTE.img LOG-VERZ
"""
import array
import importlib.machinery
import importlib.util
import os
import shutil
import sys
import tempfile
import time
import wave

_l = importlib.machinery.SourceFileLoader(
    "install_test", os.path.join(os.path.dirname(os.path.abspath(__file__)), "install-test.py"))
_s = importlib.util.spec_from_loader("install_test", _l)
it = importlib.util.module_from_spec(_s)
_l.exec_module(it)
Fehler, VM, ok, schritt = it.Fehler, it.VM, it.ok, it.schritt
_d = importlib.machinery.SourceFileLoader(
    "desktop_test", os.path.join(os.path.dirname(os.path.abspath(__file__)), "desktop-test.py"))
_ds = importlib.util.spec_from_loader("desktop_test", _d)
dt = importlib.util.module_from_spec(_ds)
_d.exec_module(dt)


def ton_auswerten(pfad):
    """Sucht in der WAV-Datei von QEMU den lautesten Abschnitt; gibt (Sekunden mit Signal,
    Spitze in dBFS, Frequenz in Hz) zurueck."""
    with wave.open(pfad, "rb") as w:
        rate, kan, breite = w.getframerate(), w.getnchannels(), w.getsampwidth()
        if breite != 2:
            raise Fehler(f"WAV mit {8 * breite} Bit statt 16")
        daten = array.array("h", w.readframes(w.getnframes()))
    mono = daten[::kan]
    if not mono:
        raise Fehler("WAV-Datei von QEMU ist leer")
    block = rate // 10
    laut = [i for i in range(0, len(mono) - block, block)
            if max(abs(x) for x in mono[i:i + block]) > 1000]
    if not laut:
        return 0.0, None, None
    import math
    spitze = max(abs(x) for x in mono)
    # Frequenz ueber Nulldurchgaenge im laengsten Stueck mit Signal
    stuecke, start = [], laut[0]
    for a, b in zip(laut, laut[1:] + [None]):
        if b != a + block:
            stuecke.append((start, a + block))
            start = b
    s, e = max(stuecke, key=lambda x: x[1] - x[0])
    abschnitt = mono[s:e]
    nulldurchgaenge = sum(1 for x, y in zip(abschnitt, abschnitt[1:]) if (x < 0) != (y < 0))
    frequenz = nulldurchgaenge / 2 / (len(abschnitt) / rate)
    return len(laut) * block / rate, round(20 * math.log10(spitze / 32768), 1), round(frequenz)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    platte, logdir = sys.argv[1:]
    os.makedirs(logdir, exist_ok=True)
    logdir = os.path.abspath(logdir)
    wav = os.path.join(logdir, "qemu-ausgabe.wav")
    tmp = tempfile.mkdtemp(prefix="veyra-audio-test.")
    ton = ["-device", "ich9-intel-hda", "-device", "hda-duplex,audiodev=ton",
           "-audiodev", f"wav,id=ton,path={wav}"]
    vm = None
    try:
        schritt("Start mit HD-Audio (ich9-intel-hda, hda-duplex), Ausgabe als WAV auf dem Wirt")
        vm = VM(platte, os.path.join(logdir, "audio.log"), tmp, extra=ton)
        vm.erwarte(r"veyra login:", 300)
        try:
            vm.erwarte(r"VEYRA-SELBSTTEST: (OK|FEHLER)\b", 300)
        except Fehler:
            pass
        dt.anmelden_root(vm)
        vm.befehl("cat /proc/asound/cards; echo K-$((1+1))", r"\[[^\]]*\]: [\s\S]*K-2", 30)
        ok("Kernel erkennt die HD-Audio-Karte")
        vm.befehl("sleep 5; journalctl -b --no-pager -u veyra-pipewire -u veyra-wireplumber "
                  "-u veyra-pipewire-pulse | tail -40; echo J-$((1+2))", r"J-3", 60)
        vm.befehl("for i in $(seq 30); do systemctl is-active --quiet veyra-pipewire veyra-wireplumber "
                  "veyra-pipewire-pulse && break; sleep 1; done; "
                  "systemctl is-active veyra-pipewire veyra-wireplumber veyra-pipewire-pulse; echo D-$((2+2))",
                  r"active\s*\r?\n\s*active\s*\r?\n\s*active\s*\r?\n[\s\S]*D-4", 60)
        ok("veyra-pipewire, veyra-wireplumber und veyra-pipewire-pulse laufen")
        # WirePlumber braucht nach dem Start einen Moment, bis die ALSA-Geraete da sind.
        vm.befehl(". /etc/profile.d/veyra-audio.sh; for i in $(seq 20); do "
                  "veyra-audio geraete | grep -q 'eingabe' && veyra-audio geraete | grep -q 'ausgabe' && break; "
                  "sleep 1; done; veyra-audio status; veyra-audio geraete; echo G-$((3+3))",
                  r"Standard-ausgabe: [^\r\n]*\(ID \d+\)[\s\S]*Standard-eingabe: [^\r\n]*\(ID \d+\)"
                  r"[\s\S]*\*\s+\d+\s+ausgabe[\s\S]*G-6", 60)
        ok("WirePlumber meldet Standard-Ausgabe und -Eingabe")
        vm.befehl("useradd -m -G pipewire tontest && su - tontest -c 'veyra-audio geraete' | grep -c '^\\*'; "
                  "useradd -m ohneton && su - ohneton -c 'veyra-audio geraete' 2>&1 | tail -1; echo U-$((4+4))",
                  r"\r?\n2\s*\r?\n[\s\S]*veyra-audio: kein PipeWire[^\r\n]*[\s\S]*U-8", 60)
        ok("Benutzer der Gruppe pipewire sieht die Geraete, andere nicht")
        vm.befehl("veyra-audio lautstaerke 80 && veyra-audio stumm aus && "
                  "su - tontest -c 'veyra-audio test --sekunden 3'; echo T-$?",
                  r"Testton fertig[\s\S]*T-0", 60)
        ok("veyra-audio test spielt als Benutzer tontest")
        vm.befehl("veyra-audio aufnahme-test --sekunden 2; echo A-$?", r"Aufnahme: [12]\.\d s[\s\S]*A-[01]", 60)
        ok("Aufnahmeweg funktioniert (QEMU liefert Stille, Pegel nur auf Hardware pruefbar)")
        vm.befehl("python3 -c 'import wave,array,math;w=wave.open(\"/tmp/a.wav\",\"wb\");w.setnchannels(1);"
                  "w.setsampwidth(2);w.setframerate(48000);w.writeframes(array.array(\"h\",(int(9000*math.sin("
                  "2*math.pi*660*i/48000)) for i in range(48000))).tobytes())'; "
                  "aplay -q /tmp/a.wav; echo P-$?", r"P-0", 60)
        ok("aplay (ALSA) spielt ueber PipeWire")
        vm.befehl("veyra-audio stumm an && veyra-audio lautstaerke 35; echo L-$?", r"Volume: 0\.35[\s\S]*L-0", 30)
        ok("Lautstaerke und Stummschaltung")
        vm.befehl("veyra-audio diagnose | grep -c '^====='; journalctl -b -u veyra-wireplumber --no-pager | tail -15; "
                  "echo J-$((5+5))", r"J-10", 60)
        vm.sende("poweroff\r")
        ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
        sekunden, spitze, frequenz = ton_auswerten(wav)
        print(f"QEMU-Ausgabe: {sekunden:.1f} s mit Signal, Spitze {spitze} dBFS, Frequenz {frequenz} Hz")
        if sekunden < 2.5:
            raise Fehler(f"zu wenig Ton in der QEMU-Ausgabe ({sekunden:.1f} s, erwartet 3 s Testton und 1 s aplay)")
        if spitze is None or spitze < -30:
            raise Fehler(f"Ton zu leise ({spitze} dBFS)")
        if not (400 <= frequenz <= 480 or 620 <= frequenz <= 700):
            raise Fehler(f"Frequenz {frequenz} Hz passt weder zum Testton (440 Hz) noch zu aplay (660 Hz)")
        ok("QEMU hat den Ton empfangen: Pegel und Frequenz stimmen")
    except Fehler as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        log = os.path.join(logdir, "audio.log")
        if os.path.exists(log):
            with open(log, errors="replace") as h:
                print("".join(h.readlines()[-200:]))
        return 1
    finally:
        if vm:
            vm.stopp()
        shutil.rmtree(tmp, ignore_errors=True)
    print("ERFOLG: Ton ueber PipeWire in QEMU (Wiedergabe gemessen, Aufnahmeweg geprueft)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
