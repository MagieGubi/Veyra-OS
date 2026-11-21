#!/usr/bin/env python3
"""Energie (Veyra 0.7) in QEMU: startet das Abbild mit veyra-power und ACPI-S3 (QEMU bietet
S3 nur mit "-global ICH9-LPC.disable_s3=0" an). Die Echtzeituhr weckt die VM.

Geprueft wird:
  - veyra-power.service hat das Profil beim Start angewendet, "veyra-power status" laeuft
    (in QEMU ohne Akku und ohne CPU-Taktsteuerung)
  - Ruhezustand s2idle: einschlafen, von der Echtzeituhr geweckt werden, weiterarbeiten
  - Ruhezustand deep (S3), wenn die VM ihn anbietet
  - nach dem Aufwachen laufen Netzwerk und Anmeldung weiter, keine Dienste mit Fehlern
  - Profil setzen und nach einem Neustart wieder anwenden

Akku, Deckel und CPU-Energieprofile auf echter Hardware: docs/power-management.md.

Aufruf: image/power-test.py PLATTE.img LOG-VERZ
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

S3 = ["-global", "ICH9-LPC.disable_s3=0"]


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    platte, logdir = sys.argv[1:]
    os.makedirs(logdir, exist_ok=True)
    logdir = os.path.abspath(logdir)
    tmp = tempfile.mkdtemp(prefix="veyra-power-test.")
    vm = None
    try:
        schritt("Start mit ACPI-S3")
        vm = VM(platte, os.path.join(logdir, "power-1.log"), tmp, extra=S3)
        vm.erwarte(r"veyra login:", 300)
        try:
            vm.erwarte(r"VEYRA-SELBSTTEST: (OK|FEHLER)\b", 300)
        except Fehler:
            pass
        dt.anmelden_root(vm)
        vm.befehl("systemctl show -p Result --value veyra-power.service | sed 's/^/ERGEBNIS=/'; "
                  "journalctl -b -u veyra-power --no-pager -o cat | tail -3; echo A-$((1+1))",
                  r"ERGEBNIS=success\s*\r?\n[\s\S]*veyra-power: \w+[\s\S]*A-2", 30)
        ok("veyra-power.service hat das Profil beim Start angewendet")
        m = vm.befehl("veyra-power status; cat /sys/power/mem_sleep | sed 's/^/ARTEN=/'; echo B-$((1+2))",
                      r"Ruhezustand:\s+\w+[\s\S]*ARTEN=([^\r\n]*)\r?\n[\s\S]*B-3", 30)
        arten = m.group(1).replace("[", "").replace("]", "").split()
        ok(f"veyra-power status (Ruhezustaende in der VM: {', '.join(arten)})")
        if "s2idle" not in arten:
            raise Fehler(f"s2idle fehlt in /sys/power/mem_sleep ({arten})")
        for art in ["s2idle"] + (["deep"] if "deep" in arten else []):
            vm.befehl(f"veyra-power schlafen --wecken 8 --art {art}; echo S-$?",
                      rf"Wieder wach: Ruhezustand {art}[^\r\n]*\r?\n[\s\S]*S-0", 180)
            vm.befehl("journalctl -k -b --no-pager -o cat | grep -E 'PM: suspend (entry|exit)' | tail -2; "
                      "systemctl is-active systemd-networkd systemd-logind | tr '\\n' ' ' | sed 's/^/DIENSTE=/'; "
                      "echo; systemctl --failed --no-legend | wc -l | sed 's/^/KAPUTT=/'; echo C-$((2+2))",
                      r"PM: suspend exit[\s\S]*DIENSTE=active active\s*\r?\n[\s\S]*KAPUTT=0\s*\r?\n[\s\S]*C-4", 60)
            ok(f"Ruhezustand {art}: eingeschlafen, von der Echtzeituhr geweckt, Dienste laufen weiter")
        if "deep" not in arten:
            print("Hinweis: die VM bietet kein S3 (deep) an; geprueft wurde nur s2idle")
        vm.befehl("veyra-power profil energiesparen; cat /etc/veyra/power.conf; echo P-$?", r"profil=energiesparen[\s\S]*P-0", 30)
        vm.sende("poweroff\r")
        ok(f"Profil gesetzt, sauber heruntergefahren ({vm.ende():.0f}s)")
        vm.stopp()

        schritt("Neustart: gespeichertes Profil wird angewendet")
        vm = VM(platte, os.path.join(logdir, "power-2.log"), tmp, extra=S3)
        vm.erwarte(r"veyra login:", 300)
        dt.anmelden_root(vm)
        vm.befehl("veyra-power profil; journalctl -b -u veyra-power --no-pager -o cat | grep -c 'veyra-power: energiesparen' "
                  "| sed 's/^/ANGEWENDET=/'; veyra-power diagnose | grep -c '^=====' | sed 's/^/TEILE=/'; echo D-$((3+3))",
                  r"energiesparen\s*\r?\nANGEWENDET=1\s*\r?\nTEILE=[1-9][\s\S]*D-6", 60)
        ok("gespeichertes Profil nach Neustart angewendet, diagnose laeuft")
        vm.sende("poweroff\r")
        ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
    except Fehler as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        if vm:
            try:
                vm.befehl("journalctl -b --no-pager -o short-monotonic | grep -iE 'PM:|suspend|resume|ACPI' | tail -40; "
                          "echo Z-$((4+4))", r"Z-8", 30)
            except Fehler:
                pass
        for n in ("power-2.log", "power-1.log"):
            log = os.path.join(logdir, n)
            if os.path.exists(log):
                with open(log, errors="replace") as h:
                    print(f"----- {n}\n" + "".join(h.readlines()[-200:]))
                break
        return 1
    finally:
        if vm:
            vm.stopp()
        shutil.rmtree(tmp, ignore_errors=True)
    print("ERFOLG: Ruhezustand und Energieprofil in QEMU")
    return 0


if __name__ == "__main__":
    sys.exit(main())
