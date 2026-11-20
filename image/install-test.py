#!/usr/bin/env python3
"""Prueft eine frisch installierte Veyra-Platte in QEMU so, wie ein Mensch sie benutzt.

Start 1 (Ersteinrichtung):
  - Login-Aufforderung und Selbsttest OK, Ersteinrichtung wartet an Konsole 1
  - root ohne Passwort wird an der seriellen Konsole abgewiesen
  - root-Passwort, Benutzer und dessen Passwort werden an Konsole 1 eingetippt
    (Tastatur der VM ueber den QEMU-Monitor, wie an einem echten Bildschirm)
  - Anmeldung als neuer Benutzer an der seriellen Konsole, Gruppe wheel,
    /etc/shadow nicht lesbar, su mit dem root-Passwort ergibt UID 0
  - Herunterfahren per su -c 'systemctl poweroff'
Start 2 (Neustart von derselben Platte):
  - Login-Aufforderung und Selbsttest OK, keine Ersteinrichtung mehr
  - Anmeldung als root mit dem neuen Passwort, System laeuft ohne Fehler
  - Booteintrag von Start 1 als gut markiert (systemd-bless-boot)
  - veyra-kernel-update traegt einen neuen Kernel ein, der absichtlich nicht startet
    (Root-Partition gibt es nicht, panic=3)
  - Herunterfahren per poweroff
Start 3 (Rueckfall): der neue Kernel scheitert dreimal (Boot-Zaehler), danach startet
  systemd-boot wieder den alten Kernel; veyra-kernel-update meldet den neuen als schlecht.

Die Platte wird beschrieben (kein snapshot): nur eine eigens erstellte virtuelle Platte
verwenden. Aufruf: image/install-test.py PLATTE.img LOG-VERZ
"""
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time

OVMF = "/usr/share/OVMF/OVMF_CODE_4M.fd"
OVMF_VARS = "/usr/share/OVMF/OVMF_VARS_4M.fd"
ROOT_PW = "veyra-wurzel-2026"
BENUTZER = "anna"
BENUTZER_PW = "anna-geheim-77"
TASTEN = {"-": "minus", "\n": "ret", " ": "spc", ".": "dot", "_": "shift-minus"}


class Fehler(Exception):
    pass


def schritt(text):
    print(f">> {text}", flush=True)


def ok(text):
    print(f"ok: {text}", flush=True)


class VM:
    def __init__(self, platte, log, tmp, cdrom=None, extra=()):
        # Jede VM bekommt ein eigenes, frisches Verzeichnis: eine abgebrochene VM hinterlaesst
        # ihre Sockets, und QEMU soll nie auf alte Dateien treffen.
        os.makedirs(tmp, exist_ok=True)
        tmp = tempfile.mkdtemp(prefix="vm.", dir=tmp)
        self.ser = os.path.join(tmp, "seriell")
        self.mon = os.path.join(tmp, "monitor")
        vars_ = os.path.join(tmp, "vars.fd")
        shutil.copy(OVMF_VARS, vars_)
        accel = "kvm" if os.access("/dev/kvm", os.W_OK) else "tcg"
        self.log = log
        self.p = subprocess.Popen([
            "qemu-system-x86_64", "-machine", f"q35,accel={accel}", "-m", "2048", "-smp", "2",
            "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF}",
            "-drive", f"if=pflash,format=raw,file={vars_}",
            *self._laufwerke(platte, cdrom),
            "-chardev", f"socket,id=s0,path={self.ser},server=on,wait=off,logfile={log}",
            "-serial", "chardev:s0",
            "-monitor", f"unix:{self.mon},server,nowait",
            "-display", "none", "-no-reboot", *extra])
        self.buf = ""
        self.pos = 0
        for _ in range(100):
            if os.path.exists(self.ser) and os.path.exists(self.mon):
                break
            time.sleep(0.1)
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(self.ser)
        self.s.setblocking(False)
        self.m = socket.socket(socket.AF_UNIX)
        self.m.connect(self.mon)
        self.m.settimeout(2)
        try:
            self.m.recv(4096)  # Begruessung des Monitors
        except socket.timeout:
            pass

    @staticmethod
    def _laufwerke(platte, cdrom):
        """Die Platte (virtio, im Gast /dev/vda); mit CDROM zusaetzlich eine CD, von der
        die Firmware zuerst startet (bootindex), wie ein eingelegter Live-Datentraeger."""
        if not cdrom:
            return ["-drive", f"file={platte},format=raw,if=virtio"]
        return ["-drive", f"if=none,id=cd,file={cdrom},format=raw,media=cdrom,readonly=on",
                "-device", "ide-cd,drive=cd,bootindex=0",
                "-drive", f"if=none,id=hd,file={platte},format=raw",
                "-device", "virtio-blk-pci,drive=hd,bootindex=1"]

    def _lies(self, warte):
        ende = time.time() + warte
        while time.time() < ende:
            try:
                d = self.s.recv(65536)
                if not d:
                    return
                self.buf += d.decode("utf-8", "replace")
            except BlockingIOError:
                time.sleep(0.1)

    def erwarte(self, muster, zeit=180):
        """Wartet auf MUSTER (Regex) in der seriellen Ausgabe ab der letzten Fundstelle."""
        rx = re.compile(muster)
        ende = time.time() + zeit
        while True:
            m = rx.search(self.buf, self.pos)
            if m:
                self.pos = m.end()
                return m
            if time.time() > ende:
                raise Fehler(f"nicht gesehen innerhalb {zeit}s: {muster!r}")
            if self.p.poll() is not None:
                raise Fehler(f"QEMU hat sich beendet, bevor {muster!r} kam")
            self._lies(0.5)

    def sende(self, text):
        """Schreibt auf die serielle Konsole (Enter = \\r)."""
        self.s.setblocking(True)
        self.s.sendall(text.encode())
        self.s.setblocking(False)

    def tippe(self, text):
        """Tippt TEXT ueber die Tastatur der VM (landet an der aktiven Konsole, tty1)."""
        for ch in text:
            taste = TASTEN.get(ch, ch)
            if not re.fullmatch(r"[a-z0-9]|[a-z-]+", taste):
                raise Fehler(f"Zeichen nicht tippbar: {ch!r}")
            self.m.sendall(f"sendkey {taste}\n".encode())
            time.sleep(0.08)
        try:
            while self.m.recv(65536):
                pass
        except socket.timeout:
            pass

    def monitor(self, cmd, warte=2):
        """Befehl an den QEMU-Monitor (HMP); gibt dessen Antwort zurueck."""
        self.m.sendall(f"{cmd}\n".encode())
        aus, ende = b"", time.time() + warte
        while time.time() < ende:
            try:
                d = self.m.recv(65536)
                if not d:
                    break
                aus += d
            except socket.timeout:
                pass
        return aus.decode("utf-8", "replace")

    def anmelden(self, name, pw, versuche=1):
        for i in range(versuche):
            self.sende("\r")
            self.erwarte(r"login: ", 60)
            self.sende(name + "\r")
            self.erwarte(r"Password: ?", 30)
            self.sende(pw + "\r")
            # Ob eine Shell antwortet, zeigt eine Marke (die Ausgabe "21" steht nicht im
            # Befehl selbst, das Echo der Eingabe zaehlt also nicht).
            time.sleep(2)
            self.sende("echo MARKE-$((20+1))\r")
            try:
                self.erwarte(r"MARKE-21", 15)
                return
            except Fehler:
                if i + 1 == versuche:
                    raise Fehler(f"Anmeldung als {name} gescheitert")
                time.sleep(5)

    def befehl(self, cmd, muster, zeit=60):
        self.sende(cmd + "\r")
        return self.erwarte(muster, zeit)

    def ende(self, zeit=240, erlaubt=30):
        """Wartet aufs Ausschalten. Dauert es laenger als ERLAUBT Sekunden, ist das ein
        Fehler; gewartet wird trotzdem bis ZEIT, damit systemd im Log zeigt, welcher
        Dienst haengt ("A stop job is running for ...")."""
        start = time.time()
        while self.p.poll() is None and time.time() - start < zeit:
            self._lies(0.5)
        dauer = time.time() - start
        if self.p.poll() is None:
            self.p.kill()
            raise Fehler(f"VM hat sich nicht innerhalb {zeit}s ausgeschaltet")
        self._lies(0.5)
        # Die serielle Ausgabe verliert beim Ausschalten gelegentlich Zeichen (im Lauf
        # 44165729224 kam nur "...ot: Power down" an). Sauber heisst deshalb: QEMU endet
        # selbst mit 0 und eine der beiden Meldungen des Ausschaltens ist vollstaendig da.
        if self.p.returncode != 0:
            raise Fehler(f"QEMU endete mit {self.p.returncode} statt 0")
        if not re.search(r"reboot: Power down|systemd-shutdown\[1\]: Powering off", self.buf):
            raise Fehler("kein sauberes Ausschalten (weder 'reboot: Power down' noch "
                         "'systemd-shutdown[1]: Powering off' im Log)")
        haengt = sorted(set(re.findall(r"A stop job is running for ([^(\r\n]+)", self.buf)))
        if dauer > erlaubt:
            raise Fehler(f"Herunterfahren dauerte {dauer:.0f}s (erlaubt {erlaubt}s); "
                         f"haengende Dienste: {', '.join(h.strip() for h in haengt) or 'keine gemeldet'}")
        return dauer

    def stopp(self):
        if self.p.poll() is None:
            self.p.kill()
            self.p.wait()


def selbsttest(vm):
    m = vm.erwarte(r"VEYRA-SELBSTTEST: (OK|FEHLER)\b", 420)
    if m.group(1) != "OK":
        raise Fehler("Selbsttest meldet FEHLER")


def start1(platte, logdir, tmp):
    schritt("Start 1: installierte Platte, Ersteinrichtung")
    vm = VM(platte, os.path.join(logdir, "start1.log"), tmp)
    try:
        vm.erwarte(r"veyra login:", 300)
        ok("Login-Aufforderung an der seriellen Konsole")
        selbsttest(vm)
        if "Ersteinrichtung: wartet an Konsole 1" not in vm.buf:
            raise Fehler("Selbsttest meldet keine wartende Ersteinrichtung")
        ok("Selbsttest OK, Ersteinrichtung wartet an Konsole 1")

        vm.sende("\r")
        vm.erwarte(r"login: ", 60)
        vm.sende("root\r")
        vm.erwarte(r"Password: ?", 30)
        vm.sende("\r")
        vm.erwarte(r"Login incorrect", 30)
        ok("root ohne Passwort abgewiesen")

        schritt("Ersteinrichtung an Konsole 1 eintippen")
        for zeile in (ROOT_PW, ROOT_PW, BENUTZER, BENUTZER_PW, BENUTZER_PW):
            vm.tippe(zeile + "\n")
            time.sleep(1.5)
        time.sleep(5)
        vm.anmelden(BENUTZER, BENUTZER_PW, versuche=6)
        ok(f"Anmeldung als {BENUTZER} mit dem eingetippten Passwort")
        vm.befehl("id; echo ID-$((1+1))", r"groups=[^\n]*\bwheel\b[^\n]*\n[^\n]*ID-2")
        ok(f"{BENUTZER} ist in der Gruppe wheel")
        vm.befehl("cat /etc/shadow > /dev/null 2>&1 || echo SHADOW-ZU-$((3+4))", r"SHADOW-ZU-7")
        ok("/etc/shadow fuer Benutzer nicht lesbar")
        vm.befehl("test -e /var/lib/veyra/einrichtung-fertig && echo FERTIG-$((2+3))", r"FERTIG-5")
        ok("Ersteinrichtung abgeschlossen")
        vm.befehl("tr -d '\\000' < /sys/firmware/efi/efivars/LoaderInfo-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f; "
                  "echo; echo LADER-$((6+7))", r"systemd-boot [0-9][^\n]*\n[^\n]*LADER-13")
        ok("gestartet ueber systemd-boot (EFI-Variable LoaderInfo)")
        vm.befehl("su -c 'echo UID-$(id -u)-$((5+5))' root", r"Password: ?")
        vm.sende(ROOT_PW + "\r")
        vm.erwarte(r"UID-0-10", 30)
        ok("su mit dem root-Passwort ergibt UID 0")
        # Fuer die Fehlersuche, falls das Herunterfahren haengt: wer laeuft wo.
        vm.befehl("ps -eo pid,ppid,user,stat,cgroup:60,args --no-headers | grep -v ' \\[' ; "
                  "echo PS-$((4+4))", r"PS-8")
        vm.befehl("su -c 'systemctl poweroff' root", r"Password: ?")
        vm.sende(ROOT_PW + "\r")
        ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
    finally:
        vm.stopp()


def start2(platte, logdir, tmp):
    schritt("Start 2: Neustart von derselben Platte")
    vm = VM(platte, os.path.join(logdir, "start2.log"), tmp)
    try:
        vm.erwarte(r"veyra login:", 300)
        selbsttest(vm)
        if "Ersteinrichtung: wartet" in vm.buf:
            raise Fehler("Ersteinrichtung laeuft nach dem Neustart erneut")
        ok("Neustart: Login-Aufforderung, Selbsttest OK, keine Ersteinrichtung mehr")
        vm.anmelden("root", ROOT_PW, versuche=2)
        ok("Anmeldung als root mit dem neuen Passwort")
        vm.befehl("cat /etc/veyra/variante; echo VAR-$((6+6))", r"system\s*\r?\n[^\n]*VAR-12")
        vm.befehl("systemctl is-system-running; echo LAUF-$((7+7))", r"running\s*\r?\n[^\n]*LAUF-14")
        ok("Variante system, systemd meldet running")
        vm.befehl("findmnt -n -o SOURCE,FSTYPE /; echo ROOT-$((8+8))", r"ext4\s*\r?\n[^\n]*ROOT-16")
        ok("Root ist ext4 von der installierten Platte")
        # Boot-Zaehler: Start 1 lief vollstaendig, also hat systemd-bless-boot den Eintrag
        # veyra-VERSION+3.conf in veyra-VERSION.conf umbenannt (gilt jetzt als gut).
        vm.befehl("ls /efi/loader/entries/; echo EINTRAG-$((10+3))",
                  r"veyra-[0-9.]+-veyra[0-9]+\.conf\s*\r?\n[^\n]*EINTRAG-13")
        ok("Booteintrag nach vollstaendigem Start als gut markiert (systemd-bless-boot)")
        vm.befehl("systemctl is-active veyra-rootpruefung; test -e /run/issue.d/50-veyra-root.issue "
                  "|| echo KEINE-WARNUNG-$((9+9))", r"active\s*\r?\n[^\n]*KEINE-WARNUNG-18")
        ok("Startpruefung gelaufen, keine Warnung bei einer Veyra-Platte")
        # Kernel-Update mit einem Kernel, der nicht startet: derselbe Kernel, aber eine
        # Root-Partition, die es nicht gibt. panic=3 startet neu; QEMU (-no-reboot) endet dann.
        vm.befehl("veyra-kernel-update installiere /efi/veyra/$(uname -r)/linux 6.18.99-kaputt; "
                  "echo KU-$?-$((1+1))", r"KU-0-2", 120)
        vm.befehl("sed -i 's/^options .*/options    root=PARTUUID=00000000-0000-0000-0000-000000000000 "
                  "rootwait=5 panic=3/' /efi/loader/entries/veyra-6.18.99-kaputt+3.conf && sync; "
                  "echo SED-$?-$((2+2))", r"SED-0-4")
        vm.befehl("veyra-kernel-update liste; echo KL-$((3+3))", r"6\.18\.99-kaputt +ungeprueft, noch 3[^\n]*\n[^\n]*gut +<- laeuft[^\n]*\n[^\n]*KL-6")
        ok("veyra-kernel-update: neuer (kaputter) Kernel neben dem laufenden eingetragen")
        vm.sende("poweroff\r")
        ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
    finally:
        vm.stopp()


def start3(platte, logdir, tmp):
    schritt("Start 3: neuer Kernel scheitert, Rueckfall ueber den Boot-Zaehler")
    fehlstarts = 0
    for versuch in range(1, 6):
        vm = VM(platte, os.path.join(logdir, f"start3-{versuch}.log"), tmp)
        try:
            # Bis zur Anmeldung oder bis QEMU endet (Neustart nach panic=3, -no-reboot). Die
            # serielle Ausgabe verliert manchmal Zeichen; deshalb zaehlt jedes der Zeichen
            # einer Panik (auch "ebooting in" ohne das R; Lauf 44728194650 verlor genau das)
            # und erst nach dem Ende von QEMU wird ausgewertet.
            bis = time.time() + 300
            while "veyra login:" not in vm.buf and vm.p.poll() is None:
                if time.time() > bis:
                    raise Fehler("weder Anmeldung noch Neustart innerhalb 300s")
                vm._lies(0.5)
            if "veyra login:" not in vm.buf:
                vm._lies(1)
                if not re.search(r"Kernel panic|Unable to mount root|Cannot open root device|ebooting in \d+ seconds", vm.buf):
                    raise Fehler("QEMU endete ohne Anmeldung und ohne Kernel panic")
                fehlstarts += 1
                ok(f"Versuch {versuch}: neuer Kernel startet nicht (Kernel panic), Neustart")
                continue
            if fehlstarts != 3:
                raise Fehler(f"{fehlstarts} Fehlstarts statt 3 vor dem Rueckfall")
            ok("nach 3 Fehlstarts startet wieder der alte Kernel bis zur Anmeldung")
            vm.anmelden("root", ROOT_PW, versuche=3)
            vm.befehl("uname -r; echo UN-$((4+5))", r"veyra[0-9]+\s*\r?\n[^\n]*UN-9")
            vm.befehl("veyra-kernel-update liste; echo KL-$((5+5))",
                      r"6\.18\.99-kaputt +schlecht[^\n]*\n[^\n]*gut +<- laeuft[^\n]*\n[^\n]*KL-10")
            ok("veyra-kernel-update liste: neuer Kernel schlecht, alter laeuft")
            vm.befehl("veyra-kernel-update entferne 6.18.99-kaputt; echo KE-$?-$((6+6))", r"KE-0-12")
            ok("schlechten Kernel entfernt")
            vm.sende("poweroff\r")
            ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
            return
        finally:
            vm.stopp()
    raise Fehler("auch nach 5 Starts keine Anmeldung: Rueckfall auf den alten Kernel fehlt")


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    platte, logdir = sys.argv[1], sys.argv[2]
    os.makedirs(logdir, exist_ok=True)
    for f in (OVMF, OVMF_VARS, platte):
        if not os.path.exists(f):
            print(f"fehlt: {f}", file=sys.stderr)
            return 1
    tmp = tempfile.mkdtemp(prefix="veyra-install-test.")
    try:
        start1(platte, logdir, tmp)
        start2(platte, logdir, tmp)
        start3(platte, logdir, tmp)
    except Fehler as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        for f in sorted(os.listdir(logdir)):
            print(f"----- {f} (Ende) -----")
            with open(os.path.join(logdir, f), errors="replace") as h:
                print("".join(h.readlines()[-200:]))
        return 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("ERFOLG: Ersteinrichtung, Anmeldung, su, Neustart und Kernel-Rueckfall der installierten Platte")
    return 0


if __name__ == "__main__":
    sys.exit(main())
