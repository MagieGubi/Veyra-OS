#!/usr/bin/env python3
"""Bluetooth (Veyra 0.7) in QEMU: startet das Entwicklungsabbild mit @veyra-bluetooth. QEMU hat
keinen Bluetooth-Funk; im Gast erzeugt der BlueZ-Emulator btvirt ueber das Kernelmodul
hci_vhci zwei virtuelle Controller, die sich gegenseitig sehen. Der erste ist "der Rechner",
der zweite spielt das Geraet, das gekoppelt wird.

Geprueft wird:
  - der Kernel laedt hci_vhci; sobald die Controller da sind, startet bluetooth.service von
    selbst (bluetooth.target, wie beim Einstecken eines USB-Bluetooth-Adapters), BlueZ meldet
    beide Controller
  - "veyra-bluetooth suche" findet den zweiten Controller
  - "veyra-bluetooth koppeln" koppelt, vertraut und verbindet; die Kopplung uebersteht einen
    Neustart von bluetoothd
  - trennen, entfernen; diagnose enthaelt keine Geraeteadressen
  - Mitglieder der Gruppe bluetooth duerfen BlueZ ansprechen, andere Benutzer nicht

Was QEMU nicht kann (echte Funkstrecke, Kopfhoerer mit A2DP, Maus mit HID, Firmware fuer
Intel-Chips) steht in docs/bluetooth.md als Test auf echter Hardware.

Aufruf: image/bluetooth-test.py PLATTE.img LOG-VERZ
"""
import importlib.machinery
import importlib.util
import os
import shutil
import sys
import tempfile

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

ADR = r"((?:[0-9A-F]{2}:){5}[0-9A-F]{2})"


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    platte, logdir = sys.argv[1:]
    os.makedirs(logdir, exist_ok=True)
    log = os.path.join(os.path.abspath(logdir), "bluetooth.log")
    tmp = tempfile.mkdtemp(prefix="veyra-bt-test.")
    vm = None
    try:
        schritt("Start des Abbilds mit @veyra-bluetooth")
        vm = VM(platte, log, tmp)
        vm.erwarte(r"veyra login:", 300)
        try:
            vm.erwarte(r"VEYRA-SELBSTTEST: (OK|FEHLER)\b", 300)
        except Fehler:
            pass
        dt.anmelden_root(vm)
        # Zwei virtuelle Controller (BR/EDR und LE) ueber /dev/vhci
        vm.befehl("modprobe hci_vhci && (/usr/lib/bluetooth/btvirt -l2 >/tmp/btvirt.log 2>&1 &) ; "
                  "for i in $(seq 20); do [ \"$(timeout 5 bluetoothctl list | grep -c '^Controller')\" -ge 2 ] && break; "
                  "sleep 1; done; timeout 5 bluetoothctl list; ls /sys/class/bluetooth; echo C-$((2+2))",
                  r"C-4", 60)
        vm.befehl("for i in $(seq 30); do systemctl is-active --quiet bluetooth && break; sleep 1; done; "
                  "systemctl is-active bluetooth | sed 's/^/DIENST=/'; echo S-$((1+1))", r"DIENST=active\s*\r?\n[\s\S]*S-2", 60)
        ok("bluetooth.service startet, sobald ein Controller da ist (bluetooth.target)")
        m = vm.befehl("bluetoothctl list | sed -n 's/^Controller \\([0-9A-F:]*\\) .*\\[default\\].*/RECHNER=\\1/p'; "
                      "bluetoothctl list | grep -v default | sed -n 's/^Controller \\([0-9A-F:]*\\) .*/GERAET=\\1/p'; "
                      "echo A-$((3+3))", rf"RECHNER={ADR}\s*\r?\nGERAET={ADR}\s*\r?\n[\s\S]*A-6", 30)
        rechner, geraet = m.group(1), m.group(2)
        ok(f"zwei virtuelle Controller (hci_vhci, btvirt): {rechner} und {geraet}")
        vm.befehl("veyra-bluetooth status; echo T-$?", r"Controller [^\r\n]*\(Standard\): an[\s\S]*T-0", 30)
        ok("veyra-bluetooth status")
        # Das "Geraet" sichtbar und koppelbar machen (bluetoothctl mit select, eine Sitzung)
        vm.befehl(f"{{ echo 'select {geraet}'; sleep 1; echo 'power on'; sleep 1; echo 'pairable on'; sleep 1; "
                  f"echo 'discoverable on'; sleep 2; echo quit; }} | bluetoothctl >/tmp/geraet.log 2>&1; "
                  f"grep -c 'succeeded' /tmp/geraet.log; echo V-$((4+4))", r"V-8", 30)
        vm.befehl(f"veyra-bluetooth suche --sekunden 10 | tee /tmp/suche.log; grep -c '^{geraet} ' /tmp/suche.log | sed 's/^/GEFUNDEN=/'; "
                  f"echo F-$((5+5))", r"GEFUNDEN=1\s*\r?\n[\s\S]*F-10", 60)
        ok("veyra-bluetooth suche findet das Geraet")
        vm.befehl(f"veyra-bluetooth koppeln {geraet} --ohne-rueckfrage; echo K-$?",
                  r"Gekoppelt und vertraut: [\s\S]*K-0", 90)
        ok("koppeln: gekoppelt und vertraut")
        vm.befehl("systemctl restart bluetooth; sleep 3; veyra-bluetooth geraete; echo G-$((6+6))",
                  rf"{geraet}\s+[^\r\n]*gekoppelt[^\r\n]*vertraut[\s\S]*G-12", 60)
        ok("Kopplung uebersteht den Neustart von bluetoothd")
        vm.befehl(f"veyra-bluetooth verbinde {geraet}; veyra-bluetooth trenne {geraet}; echo V-$?",
                  rf"Getrennt: {geraet}[\s\S]*V-0", 60)
        ok("verbinden und trennen")
        # Abschnitte zaehlen; danach duerfen keine echten Adressen mehr vorkommen (nur xx:xx:...)
        vm.befehl("veyra-bluetooth diagnose > /tmp/diag.txt; grep -c '^=====' /tmp/diag.txt | sed 's/^/TEILE=/'; "
                  "grep -cE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' /tmp/diag.txt | sed 's/^/ROH=/'; echo D-$((7+7))",
                  r"TEILE=[1-9]\d*\s*\r?\nROH=0\s*\r?\n[\s\S]*D-14", 60)
        ok("diagnose ohne Geraeteadressen")
        vm.befehl("useradd -m -G bluetooth blau && su - blau -c 'veyra-bluetooth geraete' >/dev/null; echo B-$?",
                  r"B-0", 60)
        # Ohne Zugriff wartet bluetoothctl endlos auf bluetoothd, daher timeout.
        vm.befehl("useradd -m fremd && su - fremd -c 'timeout 5 bluetoothctl list' 2>&1 | grep -c '^Controller' "
                  "| sed 's/^/FREMD=/'; echo Y-$((10+10))", r"FREMD=0\s*\r?\n[\s\S]*Y-20", 60)
        ok("Gruppe bluetooth darf BlueZ ansprechen, andere Benutzer nicht")
        vm.befehl(f"veyra-bluetooth entferne {geraet}; echo E-$?", rf"Entfernt: {geraet}[\s\S]*E-0", 30)
        ok("entfernen")
        vm.befehl("journalctl -b -u bluetooth --no-pager | tail -30; echo J-$((11+11))", r"J-22", 30)
        vm.sende("poweroff\r")
        ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
    except Fehler as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        if vm:
            try:
                vm.befehl("journalctl -b -u bluetooth --no-pager | tail -40; cat /tmp/btvirt.log /tmp/geraet.log; "
                          "echo Z-$((12+12))", r"Z-24", 30)
            except Fehler:
                pass
        if os.path.exists(log):
            with open(log, errors="replace") as h:
                print("".join(h.readlines()[-200:]))
        return 1
    finally:
        if vm:
            vm.stopp()
        shutil.rmtree(tmp, ignore_errors=True)
    print("ERFOLG: Bluetooth in QEMU (zwei virtuelle Controller: suchen, koppeln, verbinden, Rechte)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
