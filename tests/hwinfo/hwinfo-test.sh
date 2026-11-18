#!/usr/bin/env bash
# Tests fuer veyra-hwinfo (packages/base/veyra-hwinfo) mit einem nachgebauten /sys und /proc
# nach dem Vorbild von Adrians Laptop (Intel-CPU, Intel- und NVIDIA-Grafik, Intel-WLAN,
# NVMe, HD-Audio). Die Ausgabe in QEMU prueft der Selbsttest.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
pkg=$here/packages/base/veyra-hwinfo
t=$(mktemp -d)
trap '[ -n "${BEHALTEN:-}" ] || rm -rf "$t"' EXIT
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
ok() { echo "ok $n - $1"; }
hw() { python3 "$pkg/veyra-hwinfo" --root "$t/r" "$@"; }

n=$((n + 1))
grep -q "$(sha256sum "$pkg/veyra-hwinfo" | cut -d' ' -f1)" "$pkg/recipe.sh" \
  || fail "sha256sums in $pkg/recipe.sh passt nicht zu veyra-hwinfo"
ok "Rezept passt zum Programm"

python3 - "$t/r" <<'PY'
import os, sys
r = sys.argv[1]
def f(p, inhalt):
    p = os.path.join(r, p.lstrip("/")); os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(inhalt + "\n")
def link(p, ziel):
    p = os.path.join(r, p.lstrip("/")); os.makedirs(os.path.dirname(p), exist_ok=True); os.symlink(ziel, p)
cpu = ""
for i in range(16):
    cpu += (f"processor\t: {i}\nmodel name\t: 13th Gen Intel(R) Core(TM) i7-13620H\nphysical id\t: 0\n"
            f"core id\t\t: {i // 2 if i < 12 else i - 6}\nflags\t\t: fpu vmx sse\n\n")
f("/proc/cpuinfo", cpu)
f("/proc/meminfo", "MemTotal:       32542000 kB\nMemFree: 1 kB")
for k, v in {"sys_vendor": "Micro-Star International Co., Ltd.", "product_name": "Katana 15 B13VFK",
             "board_vendor": "Micro-Star International Co., Ltd.", "board_name": "MS-1585",
             "bios_version": "E1585IMS.10D", "bios_date": "05/10/2024", "product_serial": "GEHEIM-123"}.items():
    f(f"/sys/class/dmi/id/{k}", v)
os.makedirs(os.path.join(r, "sys/firmware/efi/efivars"))
open(os.path.join(r, "sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"), "wb").write(b"\x06\0\0\0\x01")
pci = {"0000:00:00.0": ("8086", "a706", "060000", None), "0000:00:02.0": ("8086", "a7a8", "030000", "i915"),
       "0000:01:00.0": ("10de", "28e0", "030000", None), "0000:00:1f.3": ("8086", "51ca", "040380", "snd_hda_intel"),
       "0000:00:14.3": ("8086", "51f1", "028000", None), "0000:02:00.0": ("1344", "5411", "010802", "nvme"),
       "0000:00:14.0": ("8086", "51ed", "0c0330", "xhci_hcd")}
for a, (v, d, k, tr) in pci.items():
    b = f"/sys/bus/pci/devices/{a}"
    f(b + "/vendor", "0x" + v); f(b + "/device", "0x" + d); f(b + "/class", "0x" + k)
    if tr:
        link(b + "/driver", f"../../../bus/pci/drivers/{tr}")
f("/sys/bus/usb/devices/1-1/idVendor", "8087"); f("/sys/bus/usb/devices/1-1/idProduct", "0033")
f("/sys/bus/usb/devices/1-1/serial", "GEHEIM-USB")
link("/sys/bus/usb/devices/1-1/1-1:1.0/driver", "../../../../bus/usb/drivers/btusb")
f("/sys/bus/usb/devices/1-2/idVendor", "1058"); f("/sys/bus/usb/devices/1-2/idProduct", "2620")
f("/sys/bus/usb/devices/1-2/manufacturer", "Western Digital"); f("/sys/bus/usb/devices/1-2/product", "Elements SE SSD")
f("/sys/block/nvme0n1/size", str(1000204886016 // 512)); f("/sys/block/nvme0n1/removable", "0")
f("/sys/block/nvme0n1/queue/rotational", "0"); f("/sys/class/nvme/nvme0/model", "Micron 2400 MTFDKBA1T0QFM")
f("/sys/class/nvme/nvme0/serial", "GEHEIM-NVME")
f("/sys/devices/usb1/1-2/host0/block/sda/size", str(2000398934016 // 512))
f("/sys/devices/usb1/1-2/host0/block/sda/removable", "0")
f("/sys/devices/usb1/1-2/host0/block/sda/device/model", "Elements SE SSD")
link("/sys/block/sda", "../devices/usb1/1-2/host0/block/sda")
f("/sys/block/sdb/size", "0")
f("/sys/class/net/enp3s0/operstate", "down"); f("/sys/class/net/enp3s0/speed", "-1")
f("/sys/class/net/enp3s0/address", "aa:bb:cc:dd:ee:ff")
link("/sys/class/net/enp3s0/device/driver", "../../../bus/pci/drivers/r8169")
os.makedirs(os.path.join(r, "sys/class/net/lo"))
link("/sys/class/drm/card1/device/driver", "../../../bus/pci/drivers/i915")
os.makedirs(os.path.join(r, "sys/class/drm/card1-eDP-1"))
f("/sys/class/sound/card0/id", "PCH")
PY

n=$((n + 1))
hw > "$t/text"
for z in 'CPU:          13th Gen Intel(R) Core(TM) i7-13620H (10 Kerne, 16 Threads, VT-x)' \
         'Speicher:     31779 MiB' 'System:       Micro-Star International Co., Ltd. Katana 15 B13VFK' \
         'Firmware:     UEFI, Secure Boot an'; do
  grep -qxF "$z" "$t/text" || fail "Zeile fehlt: $z"$'\n'"$(head -6 "$t/text")"
done
ok "CPU (Kerne und Threads), Speicher, System und Secure Boot"

n=$((n + 1))
grep -q '^  nvme0n1 *NVMe *Micron 2400 MTFDKBA1T0QFM *931.5 GiB' "$t/text" || fail "NVMe fehlt: $(grep -A3 Datentraeger "$t/text")"
grep -q '^  sda *USB *Elements SE SSD *1863.0 GiB' "$t/text" || fail "USB-SSD fehlt"
grep -q '^  sdb ' "$t/text" && fail "leeres Laufwerk aufgefuehrt"
ok "NVMe und USB-SSD mit Modell und Groesse, leeres Laufwerk ausgelassen"

n=$((n + 1))
grep -q '^  enp3s0 *Ethernet *Treiber r8169 *down$' "$t/text" || fail "Ethernet falsch: $(grep -A3 '^Netzwerk' "$t/text")"
grep -q 'WLAN-Chip vorhanden, aber kein WLAN-Geraet' "$t/text" || fail "fehlender WLAN-Treiber nicht gemeldet"
grep -q '0000:00:02.0 .*Intel Grafik (VGA) \[8086:a7a8\] Treiber i915' "$t/text" || fail "Intel-Grafik fehlt"
grep -q '0000:01:00.0 .*NVIDIA Grafik (VGA) \[10de:28e0\] Treiber -' "$t/text" || fail "NVIDIA-Grafik fehlt"
grep -q '0000:00:1f.3 .*Audio .*Treiber snd_hda_intel' "$t/text" || fail "Audio fehlt"
ok "Netzwerk, WLAN-Chip ohne Treiber, Intel- und NVIDIA-Grafik, Audio"

n=$((n + 1))
sed -n '/^Ohne Treiber/,$p' "$t/text" > "$t/ohne"
{ grep -q '10de:28e0' "$t/ohne" && grep -q '8086:51f1' "$t/ohne"; } || fail "Geraete ohne Treiber fehlen: $(cat "$t/ohne")"
grep -q '8086:a706' "$t/ohne" && fail "Bridge als fehlender Treiber gemeldet"
grep -q '1-1 .*\[8087:0033\] Intel, Treiber btusb' "$t/text" || fail "USB-Bluetooth fehlt"
ok "Geraete ohne Treiber aufgelistet (ohne Bridges), USB mit Treibern der Schnittstellen"

n=$((n + 1))
hw --json > "$t/json"
python3 - "$t/json" <<'PY'
import json, sys
h = json.load(open(sys.argv[1]))
assert h["version"] == 1 and h["cpu"]["threads"] == 16 and h["system"]["secure_boot"] is True
assert [w["id"] for w in h["wlan"]["pci"]] == ["8086:51f1"] and h["wlan"]["geraete"] == []
assert {d["name"] for d in h["datentraeger"]} == {"nvme0n1", "sda"}
PY
if grep -rq 'GEHEIM\|aa:bb:cc' "$t/text" "$t/json"; then fail "Seriennummer oder MAC-Adresse ausgegeben"; fi
ok "JSON vollstaendig; keine Seriennummern und MAC-Adressen in Text und JSON"

echo "Alle $n Hardware-Tests bestanden."
