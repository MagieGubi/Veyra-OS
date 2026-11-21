#!/usr/bin/env python3
"""WLAN (Veyra 0.7) in QEMU: zwei virtuelle Funkgeraete (mac80211_hwsim). wlan1 ist ein
Zugangspunkt (hostapd, nur fuer diesen Test; Adressen per DHCP und Router-Anzeige von
systemd-networkd), wlan0 ist das WLAN des Rechners und wird wie im Alltag von iwd und
veyra-network bedient.

Ablauf:
  Start 1: Test-Zugangspunkt einrichten (fester Treiber-Start beim Booten, iwd laesst das
           Funkgeraet des Zugangspunkts in Ruhe), Neustart, damit die Namen fest sind
  Start 2: WPA2-Personal verbinden: Passwort nur ueber stdin, IPv4 per DHCP, IPv6 per SLAAC;
           hostapd bestaetigt die Schluesselverwaltung (AKM 00-0f-ac-2 = PSK).
           Dann WPA3-Personal (SAE, AKM 00-0f-ac-8, Management-Frame-Schutz Pflicht).
  Start 3: ohne jeden Befehl verbindet iwd wieder mit dem bekannten WPA3-Netz (Autoconnect)

Datenverkehr zwischen zwei Schnittstellen eines Rechners geht nicht ueber Funk; Nachweis der
Funkstrecke sind deshalb Anmeldung, Schluesselaustausch, DHCP und Router-Anzeige (alle ueber
das virtuelle Funkmedium), nicht ein ping. Echte Router und echte Chips: docs/network.md.

Aufruf: image/wlan-test.py PLATTE.img LOG-VERZ
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

PASSWORT = "veyra-test-passwort"     # nur fuer den virtuellen Test-Zugangspunkt

AP_GEMEINSAM = """interface=wlan1
driver=nl80211
ctrl_interface=/run/hostapd
hw_mode=g
channel=6
wpa=2
rsn_pairwise=CCMP
"""
AP_WPA2 = AP_GEMEINSAM + f"ssid=veyra-test-wpa2\nwpa_key_mgmt=WPA-PSK\nwpa_passphrase={PASSWORT}\n"
AP_WPA3 = AP_GEMEINSAM + f"ssid=veyra-test-wpa3\nwpa_key_mgmt=SAE\nieee80211w=2\nsae_pwe=2\nsae_password={PASSWORT}\n"

NETZ_AP = """[Match]
Name=wlan1

[Network]
Address=10.77.0.1/24
Address=fd77:0:0:1::1/64
DHCPServer=yes
IPv6SendRA=yes
ConfigureWithoutCarrier=yes

[DHCPServer]
PoolOffset=100
PoolSize=50

[IPv6Prefix]
Prefix=fd77:0:0:1::/64
"""

AP_UNIT = """[Unit]
Description=Veyra WLAN-Test: Zugangspunkt auf wlan1 (nur Test)
After=sys-subsystem-net-devices-wlan1.device veyra-firewall.service systemd-networkd.service
Requires=sys-subsystem-net-devices-wlan1.device

[Service]
Type=forking
PIDFile=/run/hostapd.pid
ExecStartPre=/bin/sh -c 'nft insert rule inet veyra eingang iifname wlan1 accept'
ExecStart=/usr/bin/hostapd -B -P /run/hostapd.pid /etc/veyra-test/ap.conf

[Install]
WantedBy=multi-user.target
"""


def datei(vm, pfad, inhalt, marke):
    """Schreibt eine Datei im Gast ueber ein Here-Document (Inhalt ohne einfache Anfuehrung)."""
    vm.befehl(f"mkdir -p {os.path.dirname(pfad)}; cat > {pfad} <<'VEYRA_EOF'\r{inhalt.replace(chr(10), chr(13))}"
              f"VEYRA_EOF\recho {marke}-$((1+1))", rf"{marke}-2", 30)


def starte(platte, logname, tmp, logdir):
    v = VM(platte, os.path.join(logdir, logname), tmp)
    v.erwarte(r"veyra login:", 300)
    return v


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    platte, logdir = sys.argv[1:]
    os.makedirs(logdir, exist_ok=True)
    logdir = os.path.abspath(logdir)
    tmp = tempfile.mkdtemp(prefix="veyra-wlan-test.")
    vm = None
    try:
        schritt("Start 1: Test-Zugangspunkt einrichten")
        vm = starte(platte, "wlan-1.log", tmp, logdir)
        try:
            vm.erwarte(r"VEYRA-SELBSTTEST: (OK|FEHLER)\b", 300)
        except Fehler:
            pass
        dt.anmelden_root(vm)
        # Der Selbsttest laedt und entfernt mac80211_hwsim selbst; fuer diesen Test aus.
        vm.befehl("systemctl mask veyra-selftest.timer veyra-selftest.service >/dev/null 2>&1; echo M-$((2+3))",
                  r"M-5", 30)
        datei(vm, "/etc/modules-load.d/veyra-test-hwsim.conf", "mac80211_hwsim\n", "D1")
        datei(vm, "/etc/modprobe.d/veyra-test-hwsim.conf", "options mac80211_hwsim radios=2\n", "D2")
        datei(vm, "/etc/veyra-test/ap-wpa2.conf", AP_WPA2, "D3")
        datei(vm, "/etc/veyra-test/ap-wpa3.conf", AP_WPA3, "D4")
        datei(vm, "/etc/systemd/network/10-veyra-test-ap.network", NETZ_AP, "D5")
        datei(vm, "/etc/systemd/system/veyra-test-ap.service", AP_UNIT, "D6")
        datei(vm, "/etc/veyra-test/passwort", PASSWORT + "\n", "D7")
        # iwd soll das zweite Funkgeraet (phy1, Zugangspunkt) nicht verwalten.
        vm.befehl("x=$(sed -n 's/^ExecStart=//p' /usr/lib/systemd/system/iwd.service); mkdir -p "
                  "/etc/systemd/system/iwd.service.d; printf '[Service]\\nExecStart=\\nExecStart=%s -P phy1\\n' \"$x\" "
                  "> /etc/systemd/system/iwd.service.d/veyra-test.conf; cat /etc/systemd/system/iwd.service.d/veyra-test.conf; "
                  "ln -sf ap-wpa2.conf /etc/veyra-test/ap.conf; chmod 600 /etc/veyra-test/passwort; "
                  "systemctl enable veyra-test-ap.service 2>&1 | tail -1; echo E-$((3+4))", r"E-7", 30)
        vm.sende("poweroff\r")
        vm.ende()
        vm.stopp()
        ok("Zugangspunkt eingerichtet, Neustart")

        schritt("Start 2: WPA2 und WPA3 verbinden")
        vm = starte(platte, "wlan-2.log", tmp, logdir)
        dt.anmelden_root(vm)
        vm.befehl("for i in $(seq 30); do systemctl is-active --quiet veyra-test-ap && break; sleep 1; done; "
                  "systemctl is-active iwd veyra-test-ap; basename $(readlink /sys/class/net/wlan1/phy80211); "
                  "echo A-$((4+4))", r"active\s*\r?\nactive\s*\r?\nphy1\s*\r?\n[\s\S]*A-8", 60)
        ok("iwd und Test-Zugangspunkt laufen (wlan1 auf phy1)")
        vm.befehl("for i in $(seq 20); do veyra-network wlan liste 2>/dev/null | grep -q veyra-test-wpa2 && break; "
                  "sleep 1; done; veyra-network wlan liste; veyra-network wlan liste | grep -c 'veyra-test-wpa2' "
                  "| sed 's/^/GEFUNDEN=/'; echo L-$((5+4))", r"GEFUNDEN=[1-9][\s\S]*L-9", 60)
        ok("veyra-network wlan liste sieht das Netz")
        vm.befehl("veyra-network wlan verbinde veyra-test-wpa2 --passwort-stdin < /etc/veyra-test/passwort; "
                  "echo V-$?", r"Verbunden mit veyra-test-wpa2 \(WPA2-Personal\)[\s\S]*V-0", 90)
        vm.befehl("for i in $(seq 30); do ip -4 addr show wlan0 | grep -q 'inet 10\\.77\\.0\\.' && "
                  "ip -6 addr show wlan0 | grep -q 'inet6 fd77:0:0:1:' && break; sleep 1; done; "
                  "veyra-network wlan status; echo S-$((5+5))",
                  r"Sicherheit: WPA2-Personal[\s\S]*Adressen:[^\r\n]*10\.77\.0\.\d+/24[^\r\n]*fd77:0:0:1:[\s\S]*S-10", 60)
        vm.befehl("hostapd_cli -p /run/hostapd all_sta | grep -i AKMSuiteSelector; echo K-$((5+6))",
                  r"AKMSuiteSelector=00-0f-ac-2[\s\S]*K-11", 30)
        ok("WPA2-Personal: verbunden, IPv4 per DHCP, IPv6 per SLAAC, AKM PSK")
        vm.befehl("[ \"$(stat -c %a /var/lib/iwd/veyra-test-wpa2.psk)\" = 600 ] && echo RECHTE-OK; "
                  "veyra-network diagnose | grep -c 'veyra-test-passwort' | sed 's/^/IM-BERICHT=/'; echo R-$((6+6))",
                  r"RECHTE-OK[\s\S]*IM-BERICHT=0\s*\r?\n[\s\S]*R-12", 60)
        ok("Netzdatei nur fuer root lesbar, Passwort nicht in der Diagnose")
        vm.befehl("veyra-network wlan trenne; ln -sf ap-wpa3.conf /etc/veyra-test/ap.conf; "
                  "systemctl restart veyra-test-ap; for i in $(seq 20); do "
                  "veyra-network wlan liste 2>/dev/null | grep -q veyra-test-wpa3 && break; sleep 1; done; "
                  "veyra-network wlan verbinde veyra-test-wpa3 --passwort-stdin < /etc/veyra-test/passwort; "
                  "echo W-$?", r"Verbunden mit veyra-test-wpa3 \(WPA3-Personal\)[\s\S]*W-0", 120)
        vm.befehl("for i in $(seq 30); do ip -4 addr show wlan0 | grep -q 'inet 10\\.77\\.0\\.' && break; sleep 1; done; "
                  "hostapd_cli -p /run/hostapd all_sta | grep -i AKMSuiteSelector; veyra-network wlan status; "
                  "echo X-$((7+7))", r"AKMSuiteSelector=00-0f-ac-8[\s\S]*Sicherheit: WPA3-Personal[\s\S]*"
                  r"Adressen:[^\r\n]*10\.77\.0\.\d+/24[\s\S]*X-14", 60)
        ok("WPA3-Personal (SAE): verbunden, AKM SAE, Adresse per DHCP")
        vm.sende("poweroff\r")
        vm.ende()
        vm.stopp()

        schritt("Start 3: Autoconnect nach Neustart")
        vm = starte(platte, "wlan-3.log", tmp, logdir)
        dt.anmelden_root(vm)
        vm.befehl("for i in $(seq 60); do ip -4 addr show wlan0 | grep -q 'inet 10\\.77\\.0\\.' && break; sleep 1; done; "
                  "veyra-network wlan status; echo Z-$((8+8))",
                  r"Netz:\s+veyra-test-wpa3[\s\S]*Sicherheit: WPA3-Personal[\s\S]*Adressen:[^\r\n]*10\.77\.0\.[\s\S]*Z-16", 90)
        ok("iwd verbindet nach dem Neustart ohne Befehl mit dem bekannten WPA3-Netz")
        vm.befehl("veyra-network wlan vergiss veyra-test-wpa3; ls /var/lib/iwd; echo F-$((9+9))",
                  r"vergessen\.[\s\S]*F-18", 30)
        ok("wlan vergiss")
        vm.befehl("journalctl -b -u iwd -u veyra-test-ap --no-pager | tail -30; echo J-$((10+10))", r"J-20", 30)
        vm.sende("poweroff\r")
        ok(f"sauber heruntergefahren ({vm.ende():.0f}s)")
    except Fehler as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        if vm:
            try:
                vm.befehl("journalctl -b -u iwd -u veyra-test-ap -u systemd-networkd --no-pager | tail -60; "
                          "ip addr; iwctl station wlan0 show; echo Q-$((11+11))", r"Q-22", 30)
            except Fehler:
                pass
        for n in ("wlan-1.log", "wlan-2.log", "wlan-3.log")[::-1]:
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
    print("ERFOLG: WLAN in QEMU (WPA2, WPA3-SAE, DHCP, IPv6, Autoconnect)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
