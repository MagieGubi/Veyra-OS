#!/usr/bin/env python3
"""Desktop-Grundlage (Veyra 0.6, Phase 6) in QEMU: startet das Entwicklungsabbild mit
virtio-gpu, Tastatur und Tablet. Auf der Platte sind zusaetzlich die Pakete der Stufe 5
(@veyra-desktop) und veyra-desktop-test installiert; dessen Dienst startet als
unprivilegierter Benutzer cage mit foot ueber seatd.

Geprueft wird:
  - seatd und veyra-desktop-test laufen, cage und foot sind Prozesse des Testbenutzers
  - foot hat sein Skript ausgefuehrt (Markendatei im Laufzeitverzeichnis)
  - virtio-gpu ist als DRM-Geraet da und ein Ausgang ist verbunden
  - das Bild der Grafikkarte (QEMU screendump) zeigt Inhalt: mehrere Farben und ein
    nennenswerter Anteil Pixel, die sich vom Hintergrund unterscheiden
Das Bild wird als PNG gespeichert (CI-Artefakt).

Aufruf: image/desktop-test.py PLATTE.img LOG-VERZ
"""
import importlib.machinery
import importlib.util
import os
import shutil
import struct
import sys
import tempfile
import time
import zlib

_l = importlib.machinery.SourceFileLoader(
    "install_test", os.path.join(os.path.dirname(os.path.abspath(__file__)), "install-test.py"))
_s = importlib.util.spec_from_loader("install_test", _l)
it = importlib.util.module_from_spec(_s)
_l.exec_module(it)
Fehler, VM, ok, schritt = it.Fehler, it.VM, it.ok, it.schritt
GRAFIK = ["-vga", "virtio", "-device", "virtio-keyboard-pci", "-device", "virtio-tablet-pci"]


def lies_ppm(pfad):
    """P6-Datei (QEMU screendump) -> (breite, hoehe, rgb-bytes)."""
    with open(pfad, "rb") as f:
        d = f.read()
    teile, pos = [], 0
    while len(teile) < 4:
        while d[pos:pos + 1].isspace():
            pos += 1
        if d[pos:pos + 1] == b"#":
            pos = d.index(b"\n", pos) + 1
            continue
        start = pos
        while not d[pos:pos + 1].isspace():
            pos += 1
        teile.append(d[start:pos])
    if teile[0] != b"P6" or teile[3] != b"255":
        raise Fehler(f"unerwartetes Bildformat: {teile[0]!r} {teile[3]!r}")
    b, h = int(teile[1]), int(teile[2])
    pix = d[pos + 1:pos + 1 + b * h * 3]
    if len(pix) != b * h * 3:
        raise Fehler("Bild unvollstaendig")
    return b, h, pix


def schreibe_png(pfad, b, h, pix):
    zeilen = b"".join(b"\0" + pix[y * b * 3:(y + 1) * b * 3] for y in range(h))

    def block(typ, daten):
        return struct.pack(">I", len(daten)) + typ + daten + struct.pack(">I", zlib.crc32(typ + daten))
    with open(pfad, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + block(b"IHDR", struct.pack(">IIBBBBB", b, h, 8, 2, 0, 0, 0))
                + block(b"IDAT", zlib.compress(zeilen, 9)) + block(b"IEND", b""))


def bild_pruefen(b, h, pix):
    """Gibt (Farben, Anteil Vordergrund) zurueck; Hintergrund = haeufigste Farbe."""
    zaehler = {}
    for i in range(0, len(pix), 3 * 4):         # jedes vierte Pixel reicht
        k = pix[i:i + 3]
        zaehler[k] = zaehler.get(k, 0) + 1
    gesamt = sum(zaehler.values())
    hintergrund = max(zaehler.values())
    return len(zaehler), 1 - hintergrund / gesamt


def anmelden_root(vm):
    """Entwicklungsabbild: root an der seriellen Konsole ohne Passwort."""
    for _ in range(3):
        vm.sende("\r")
        vm.erwarte(r"login: ", 60)
        vm.sende("root\r")
        time.sleep(3)
        vm._lies(0.5)
        if vm.buf.rstrip().endswith(("Password:", "Password: ")):
            vm.sende("\r")
            time.sleep(2)
        vm.sende("echo MARKE-$((20+1))\r")
        try:
            vm.erwarte(r"MARKE-21", 15)
            return
        except Fehler:
            time.sleep(5)
    raise Fehler("Anmeldung als root gescheitert")


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    platte, logdir = sys.argv[1:]
    os.makedirs(logdir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="veyra-desktop-test.")
    vm = None
    try:
        schritt("Start mit virtio-gpu: Desktop-Testdienst (cage mit foot)")
        vm = VM(platte, os.path.join(logdir, "desktop.log"), tmp, extra=GRAFIK)
        vm.erwarte(r"veyra login:", 300)
        try:
            vm.erwarte(r"VEYRA-SELBSTTEST: (OK|FEHLER)\b", 300)
        except Fehler:
            pass
        anmelden_root(vm)
        vm.befehl("ls /sys/class/drm/; cat /sys/class/drm/card*-*/status; echo DRM-$((1+1))",
                  r"card\d[\s\S]*connected[\s\S]*DRM-2")
        ok("virtio-gpu als DRM-Geraet mit verbundenem Ausgang")
        vm.befehl("for i in $(seq 60); do [ -e /run/veyra-desktop-test/foot-laeuft ] && break; sleep 2; done; "
                  "systemctl is-active seatd veyra-desktop-test; ls /run/veyra-desktop-test/; echo F-$((2+2))",
                  r"active\s*\r?\n\s*active\s*\r?\n[\s\S]*foot-laeuft[\s\S]*F-4", 180)
        ok("seatd und veyra-desktop-test aktiv, foot hat sein Skript ausgefuehrt")
        vm.befehl("ps -o user=,comm= -C cage,foot | sort; echo P-$((3+3))",
                  r"desktest\s+cage\s*\r?\n\s*desktest\s+foot[\s\S]*P-6", 30)
        ok("cage und foot laufen als Testbenutzer (ohne root)")
        vm.befehl("journalctl -b -u veyra-desktop-test -u seatd --no-pager | tail -25; echo J-$((4+4))",
                  r"J-8", 30)
        time.sleep(3)
        ppm = os.path.join(tmp, "bild.ppm")
        antwort = vm.monitor(f"screendump {ppm}", 5)
        if not os.path.exists(ppm):
            raise Fehler(f"screendump hat kein Bild geschrieben: {antwort.strip()}")
        b, h, pix = lies_ppm(ppm)
        png = os.path.join(logdir, "veyra-desktop.png")
        schreibe_png(png, b, h, pix)
        farben, anteil = bild_pruefen(b, h, pix)
        print(f"Bild {b}x{h}, {farben} Farben, {anteil:.1%} Vordergrund -> {png}")
        if farben < 3 or anteil < 0.002:
            raise Fehler(f"Bild ohne erkennbaren Inhalt ({farben} Farben, {anteil:.2%} Vordergrund)")
        ok("Bildschirm zeigt das Terminal")
        vm.sende("poweroff\r")
        ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
    except Fehler as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        log = os.path.join(logdir, "desktop.log")
        if os.path.exists(log):
            with open(log, errors="replace") as h:
                print("".join(h.readlines()[-200:]))
        return 1
    finally:
        if vm:
            vm.stopp()
        shutil.rmtree(tmp, ignore_errors=True)
    print("ERFOLG: Wayland-Sitzung (cage, foot) startet in QEMU ueber virtio-gpu")
    return 0


if __name__ == "__main__":
    sys.exit(main())
