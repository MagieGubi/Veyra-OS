#!/usr/bin/env python3
"""Prueft veyra-recovery in QEMU an einer absichtlich beschaedigten, installierten Platte.

Start 1: Ersteinrichtung wie in image/install-test.py (root-Passwort, Benutzer).
Start 2: als root anmelden, dann absichtlich beschaedigen:
  - der (gute) Booteintrag zeigt auf eine Root-Partition, die es nicht gibt
  - /usr/bin/less (Paket less) wird ueberschrieben
Start 3: die Platte startet nicht mehr (keine Anmeldung, der Kernel wartet auf die Root).
Start 4: Live-ISO mit der Platte als zweitem Laufwerk:
  veyra-recovery liste findet sie, pruefe meldet beide Schaeden, logs zeigt das Journal,
  repariere behebt beide, pruefe danach ohne Befund.
Start 5: die Platte startet wieder, Selbsttest OK, less laeuft, vpkg check ohne Fehler,
  der reparierte Eintrag ist nach dem Start wieder als gut markiert.

Die Platte wird beschrieben: nur eine eigens erstellte virtuelle Platte verwenden.
Aufruf: image/recovery-test.py PLATTE.img LIVE.iso LOG-VERZ
"""
import importlib.machinery
import importlib.util
import os
import shutil
import sys
import tempfile
import time

_l = importlib.machinery.SourceFileLoader(
    "install_test", os.path.join(os.path.dirname(os.path.abspath(__file__)), "install-test.py"))
_s = importlib.util.spec_from_loader("install_test", _l)
it = importlib.util.module_from_spec(_s)
_l.exec_module(it)
Fehler, VM, ok, schritt = it.Fehler, it.VM, it.ok, it.schritt
NULL_UUID = "00000000-0000-0000-0000-000000000000"


def beschaedigen(platte, logdir, tmp):
    schritt("Start 2: Booteintrag und Paketdatei absichtlich beschaedigen")
    vm = VM(platte, os.path.join(logdir, "start2-beschaedigen.log"), tmp)
    try:
        vm.erwarte(r"veyra login:", 300)
        it.selbsttest(vm)
        vm.anmelden("root", it.ROOT_PW, versuche=2)
        vm.befehl("ls /efi/loader/entries/; echo EINTRAG-$((10+3))",
                  r"veyra-[0-9.]+-veyra[0-9]+\.conf\s*\r?\n[^\n]*EINTRAG-13")
        vm.befehl(f"sed -i 's/^options .*/options    root=PARTUUID={NULL_UUID} rw/' "
                  "/efi/loader/entries/veyra-$(uname -r).conf && echo kaputt > /usr/bin/less && sync; "
                  "echo KAPUTT-$?-$((2+5))", r"KAPUTT-0-7")
        vm.befehl("vpkg check less | tail -1; echo VC-$((3+5))", r"1 Fehler[^\n]*\n[^\n]*VC-8", 120)
        ok("Booteintrag zeigt auf eine fremde Partition, /usr/bin/less ist kaputt")
        vm.sende("poweroff\r")
        ok(f"heruntergefahren ({vm.ende():.0f}s)")
    finally:
        vm.stopp()


def startet_nicht(platte, logdir, tmp):
    schritt("Start 3: die beschaedigte Platte startet nicht")
    vm = VM(platte, os.path.join(logdir, "start3-startet-nicht.log"), tmp)
    try:
        bis = time.time() + 150
        while time.time() < bis and vm.p.poll() is None:
            vm._lies(1)
            if "veyra login:" in vm.buf:
                raise Fehler("die beschaedigte Platte startet trotzdem bis zur Anmeldung")
        if "Linux version" not in vm.buf:
            raise Fehler("kein Kernelstart zu sehen: Test sagt nichts ueber den Booteintrag")
        ok("Kernel startet, findet aber seine Root-Partition nicht (150 s ohne Anmeldung)")
    finally:
        vm.stopp()


def live_anmelden(vm):
    """Live-System: root ohne Passwort (Entwicklungsabbild)."""
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
    raise Fehler("Anmeldung im Live-System gescheitert")


def rettung(platte, iso, logdir, tmp):
    schritt("Start 4: Live-ISO, veyra-recovery repariert die Platte")
    vm = VM(platte, os.path.join(logdir, "start4-live.log"), tmp, cdrom=iso)
    try:
        vm.erwarte(r"veyra login:", 300)
        # Der Selbsttest des Live-Systems schreibt auf dieselbe Konsole: erst abwarten.
        try:
            vm.erwarte(r"VEYRA-SELBSTTEST: (OK|FEHLER)\b", 300)
        except Fehler:
            pass
        live_anmelden(vm)
        vm.befehl("findmnt -n -o FSTYPE /; echo LIVE-$((1+1))", r"overlay\s*\r?\n[^\n]*LIVE-2")
        ok("Live-System von CD gestartet")
        vm.befehl("veyra-recovery liste; echo L-$((1+2))",
                  r"/dev/vda: Root /dev/vda2 \(ext4\), PARTUUID [0-9a-f-]{36}, EFI-Systempartition /dev/vda1"
                  r"[^\n]*\n[^\n]*L-3", 60)
        ok("veyra-recovery liste findet das installierte System auf /dev/vda")
        vm.befehl("veyra-recovery pruefe /dev/vda 2>&1; echo P-$?-$((2+2))", r"P-(\d)-4", 900)
        aus = vm.buf[vm.buf.rfind("veyra-recovery pruefe"):]
        for erwartet in ("PROBLEM: less: Inhalt veraendert: /usr/bin/less",
                         f"root=PARTUUID={NULL_UUID} statt PARTUUID="):
            if erwartet not in aus:
                raise Fehler(f"pruefe meldet nicht: {erwartet}")
        if "P-1-4" not in aus:
            raise Fehler("pruefe endet trotz Problemen nicht mit Code 1")
        ok("pruefe meldet den falschen Booteintrag und die kaputte Paketdatei")
        vm.befehl("veyra-recovery logs /dev/vda 2>&1 | head -40; echo G-$((3+3))",
                  r"Letzte Starts laut Journal:[\s\S]*G-6", 120)
        ok("logs zeigt das Journal der installierten Platte")
        vm.befehl("veyra-recovery repariere /dev/vda --bestaetigt /dev/vda 2>&1; echo R-$?-$((4+4))",
                  r"R-(\d)-8", 900)
        aus = vm.buf[vm.buf.rfind("veyra-recovery repariere"):]
        for erwartet in ("repariert: less: Inhalt veraendert: /usr/bin/less", "repariert: Eintrag veyra-",
                         "Reparatur fertig", "R-0-8"):
            if erwartet not in aus:
                raise Fehler(f"repariere: fehlt in der Ausgabe: {erwartet}")
        ok("repariere behebt Booteintrag und Paketdatei")
        vm.befehl("veyra-recovery pruefe /dev/vda 2>&1 | tail -3; echo Q-$((5+5))",
                  r"Keine Probleme gefunden\.[^\n]*\n[^\n]*Q-10", 900)
        ok("pruefe danach ohne Befund")
        vm.sende("poweroff\r")
        ok(f"Live-System heruntergefahren ({vm.ende(erlaubt=60):.0f}s)")
    finally:
        vm.stopp()


def wieder_heil(platte, logdir, tmp):
    schritt("Start 5: die reparierte Platte startet wieder")
    vm = VM(platte, os.path.join(logdir, "start5-heil.log"), tmp)
    try:
        vm.erwarte(r"veyra login:", 300)
        it.selbsttest(vm)
        ok("Anmeldung und Selbsttest OK")
        vm.anmelden("root", it.ROOT_PW, versuche=2)
        vm.befehl("less --version | head -1; echo LV-$((6+1))", r"less \d+[^\n]*\n[^\n]*LV-7")
        vm.befehl("vpkg check | tail -1; echo VC-$((7+1))", r" 0 Fehler[^\n]*\n[^\n]*VC-8", 300)
        ok("less laeuft wieder, vpkg check ohne Fehler")
        vm.befehl("ls /efi/loader/entries/; echo EINTRAG-$((10+4))",
                  r"veyra-[0-9.]+-veyra[0-9]+\.conf\s*\r?\n[^\n]*EINTRAG-14")
        ok("reparierter Booteintrag nach vollstaendigem Start wieder als gut markiert")
        vm.sende("poweroff\r")
        ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
    finally:
        vm.stopp()


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    platte, iso, logdir = sys.argv[1:]
    os.makedirs(logdir, exist_ok=True)
    for f in (it.OVMF, it.OVMF_VARS, platte, iso):
        if not os.path.exists(f):
            print(f"fehlt: {f}", file=sys.stderr)
            return 1
    tmp = tempfile.mkdtemp(prefix="veyra-recovery-test.")
    try:
        it.start1(platte, logdir, tmp)
        beschaedigen(platte, logdir, tmp)
        startet_nicht(platte, logdir, tmp)
        rettung(platte, iso, logdir, tmp)
        wieder_heil(platte, logdir, tmp)
    except Fehler as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        for f in sorted(os.listdir(logdir)):
            print(f"----- {f} (Ende) -----")
            with open(os.path.join(logdir, f), errors="replace") as h:
                print("".join(h.readlines()[-200:]))
        return 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("ERFOLG: beschaedigte Platte startet nicht, veyra-recovery repariert sie von der Live-ISO, "
          "sie startet wieder")
    return 0


if __name__ == "__main__":
    sys.exit(main())
