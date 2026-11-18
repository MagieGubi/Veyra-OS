#!/usr/bin/env bash
# Tests fuer veyra-recovery (packages/base/veyra-recovery) mit Zielsystem, Live-Vorlage und
# EFI-Partition als Verzeichnisse. Den ganzen Ablauf mit Platten prueft der CI-Job in QEMU
# (image/recovery-test.py).
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
pkg=$here/packages/base/veyra-recovery
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
ok() { echo "ok $n - $1"; }
# py CODE...: Python mit dem Modul veyra-recovery als "vr", Arbeitsverzeichnis $t
py() {
  python3 - "$pkg/veyra-recovery" "$t" <<PY
import importlib.machinery, importlib.util, os, sys
l = importlib.machinery.SourceFileLoader("vr", sys.argv[1])
s = importlib.util.spec_from_loader("vr", l); vr = importlib.util.module_from_spec(s); l.exec_module(vr)
t = sys.argv[2]
$1
PY
}

n=$((n + 1))
grep -q "$(sha256sum "$pkg/veyra-recovery" | cut -d' ' -f1)" "$pkg/recipe.sh" \
  || fail "sha256sums in $pkg/recipe.sh passt nicht zu veyra-recovery"
ok "Rezept passt zum Programm"

# Zielsystem und Live-Vorlage mit einem Paket "demo": Programm, Link, Verzeichnis, Konfiguration
kernel() {
  python3 - "$1" "$2" <<'PY'
import struct, sys
b = bytearray(2 << 20)
b[0:2] = b"MZ"; struct.pack_into("<I", b, 0x3C, 0x80); b[0x80:0x84] = b"PE\0\0"
b[0x202:0x206] = b"HdrS"; b[0x1000:0x1000 + len(sys.argv[2])] = sys.argv[2].encode()
open(sys.argv[1], "wb").write(b)
PY
}
for d in ziel live; do
  mkdir -p "$t/$d/usr/bin" "$t/$d/usr/share/demo" "$t/$d/etc" "$t/$d/var/lib/vpkg/installed/demo" \
    "$t/$d/usr/lib/modules/6.18.56-veyra4" "$t/$d/usr/lib/systemd/boot/efi"
  printf '#!/bin/sh\necho demo\n' > "$t/$d/usr/bin/demo"
  chmod 755 "$t/$d/usr/bin/demo"
  ln -s demo "$t/$d/usr/bin/demo-link"
  echo "a=1" > "$t/$d/etc/demo.conf"
  kernel "$t/$d/usr/lib/modules/6.18.56-veyra4/vmlinuz" installiert
  printf 'MZ' > "$t/$d/usr/lib/systemd/boot/efi/systemd-bootx64.efi"
  python3 -c "import struct,sys; b=bytearray(8192); b[0:2]=b'MZ'; struct.pack_into('<I',b,0x3C,0x80); b[0x80:0x84]=b'PE\0\0'; open(sys.argv[1],'wb').write(b)" \
    "$t/$d/usr/lib/systemd/boot/efi/systemd-bootx64.efi"
done
s_demo=$(sha256sum "$t/ziel/usr/bin/demo" | cut -d' ' -f1)
s_conf=$(sha256sum "$t/ziel/etc/demo.conf" | cut -d' ' -f1)
for d in ziel live; do
  cat > "$t/$d/var/lib/vpkg/installed/demo/manifest.toml" <<TOML
format = 1
name = "demo"
version = "1.0"
release = 1

[[file]]
path = "/etc/demo.conf"
type = "file"
mode = "644"
sha256 = "$s_conf"

[[file]]
path = "/usr/bin/demo"
type = "file"
mode = "755"
sha256 = "$s_demo"

[[file]]
path = "/usr/bin/demo-link"
type = "symlink"
mode = "777"
target = "demo"

[[file]]
path = "/usr/share/demo"
type = "dir"
mode = "755"
TOML
done

n=$((n + 1))
py 'b = vr.paket_befunde(t + "/ziel", t + "/live"); assert b == [], [x.text for x in b]'
echo "a=2" > "$t/ziel/etc/demo.conf"
py 'b = vr.paket_befunde(t + "/ziel", t + "/live"); assert b == [], [x.text for x in b]'
ok "heiles System ohne Befund, geaenderte Konfiguration unter /etc zaehlt nicht"

n=$((n + 1))
echo kaputt > "$t/ziel/usr/bin/demo"
rm "$t/ziel/usr/bin/demo-link"
rmdir "$t/ziel/usr/share/demo"
py '
b = vr.paket_befunde(t + "/ziel", t + "/live")
texte = sorted(x.text for x in b)
assert texte == ["demo: Inhalt veraendert: /usr/bin/demo", "demo: Link fehlt oder zeigt woanders hin: /usr/bin/demo-link",
                 "demo: Verzeichnis fehlt: /usr/share/demo"], texte
assert all(x.reparatur for x in b)
for x in b: x.reparatur()
assert vr.paket_befunde(t + "/ziel", t + "/live") == []'
[ "$(stat -c %a "$t/ziel/usr/bin/demo")" = 755 ] || fail "Modus der zurueckgeholten Datei falsch"
[ "$(readlink "$t/ziel/usr/bin/demo-link")" = demo ] || fail "Link nicht wiederhergestellt"
[ "$(cat "$t/ziel/etc/demo.conf")" = "a=2" ] || fail "Konfiguration ueberschrieben"
[ -z "$(find "$t/ziel" -name '*.veyra-recovery')" ] || fail "Zwischendateien liegen geblieben"
ok "veraenderte Datei, fehlender Link und fehlendes Verzeichnis aus dem Live-System repariert"

n=$((n + 1))
rm "$t/ziel/usr/bin/demo"
echo anders > "$t/live/usr/bin/demo"
py '
b = vr.paket_befunde(t + "/ziel", t + "/live")
assert len(b) == 1 and b[0].reparatur is None and "neu installieren" in b[0].hinweis, [(x.text, x.hinweis) for x in b]'
[ ! -e "$t/ziel/usr/bin/demo" ] || fail "Datei aus einer falschen Vorlage geholt"
printf '#!/bin/sh\necho demo\n' > "$t/live/usr/bin/demo"
ok "Vorlage mit anderer Version wird nicht benutzt (Hinweis: Paket neu installieren)"
printf '#!/bin/sh\necho demo\n' > "$t/ziel/usr/bin/demo"; chmod 755 "$t/ziel/usr/bin/demo"

# EFI-Partition wie nach der Installation, dann absichtlich beschaedigt
uuid=0b5e7a2c-1111-4222-8333-444455556666
mkdir -p "$t/esp/loader/entries" "$t/esp/veyra/6.18.56-veyra4" "$t/esp/EFI/BOOT" "$t/esp/EFI/systemd"
cp "$t/ziel/usr/lib/systemd/boot/efi/systemd-bootx64.efi" "$t/esp/EFI/BOOT/BOOTX64.EFI"
cp "$t/ziel/usr/lib/systemd/boot/efi/systemd-bootx64.efi" "$t/esp/EFI/systemd/systemd-bootx64.efi"
printf 'timeout 3\ndefault veyra-*\neditor no\n' > "$t/esp/loader/loader.conf"
cp "$t/ziel/usr/lib/modules/6.18.56-veyra4/vmlinuz" "$t/esp/veyra/6.18.56-veyra4/linux"
printf 'title      Veyra OS\nversion    6.18.56-veyra4\nsort-key   veyra\nlinux      /veyra/6.18.56-veyra4/linux\noptions    root=PARTUUID=%s rw\n' "$uuid" \
  > "$t/esp/loader/entries/veyra-6.18.56-veyra4.conf"

n=$((n + 1))
py "b = vr.boot_befunde(t + '/esp', t + '/ziel', '$uuid'); assert b == [], [x.text for x in b]"
ok "heile EFI-Partition ohne Befund"

n=$((n + 1))
sed -i 's/^options .*/options    root=PARTUUID=00000000-0000-0000-0000-000000000000 rootwait=5 panic=3 quiet/' \
  "$t/esp/loader/entries/veyra-6.18.56-veyra4.conf"
rm "$t/esp/EFI/BOOT/BOOTX64.EFI" "$t/esp/loader/loader.conf"
head -c 100 /dev/zero > "$t/esp/veyra/6.18.56-veyra4/linux"
# ein zweiter Eintrag, dessen Kernel fehlt und den es im Zielsystem nicht gibt
printf 'title Veyra OS\nversion 6.18.99-weg\nlinux /veyra/6.18.99-weg/linux\noptions root=PARTUUID=%s rw\n' "$uuid" \
  > "$t/esp/loader/entries/veyra-6.18.99-weg+3.conf"
py "
b = vr.boot_befunde(t + '/esp', t + '/ziel', '$uuid')
texte = [x.text for x in b]
assert len(b) == 4 and all(x.reparatur for x in b), texte
for x in b: x.reparatur()
b = vr.boot_befunde(t + '/esp', t + '/ziel', '$uuid'); assert b == [], [x.text for x in b]"
e=$t/esp/loader/entries/veyra-6.18.56-veyra4+3.conf
[ -f "$e" ] || fail "reparierter Eintrag nicht als ungeprueft (+3) angelegt: $(ls "$t/esp/loader/entries")"
[ ! -e "$t/esp/loader/entries/veyra-6.18.56-veyra4.conf" ] || fail "kaputter Eintrag liegt noch da"
grep -qx "options    root=PARTUUID=$uuid rw quiet" "$e" || fail "Optionen falsch: $(grep options "$e")"
cmp -s "$t/ziel/usr/lib/modules/6.18.56-veyra4/vmlinuz" "$t/esp/veyra/6.18.56-veyra4/linux" || fail "Kernel nicht zurueckgeholt"
cmp -s "$t/ziel/usr/lib/systemd/boot/efi/systemd-bootx64.efi" "$t/esp/EFI/BOOT/BOOTX64.EFI" || fail "systemd-boot nicht zurueckgeholt"
grep -qx 'default veyra-\*' "$t/esp/loader/loader.conf" || fail "loader.conf nicht neu geschrieben"
[ -f "$t/esp/loader/entries/veyra-6.18.99-weg+0.conf" ] || fail "Eintrag ohne Kernel nicht als schlecht markiert"
ok "falsche Root-Angabe, kaputter Kernel, fehlendes systemd-boot und loader.conf repariert; Eintrag ohne Kernel als schlecht markiert"

n=$((n + 1))
rm "$t/esp/loader/entries/veyra-6.18.56-veyra4+3.conf"
py "
b = vr.boot_befunde(t + '/esp', t + '/ziel', '$uuid')
assert [x.text for x in b] == ['kein Booteintrag fuer den installierten Kernel 6.18.56-veyra4'], [x.text for x in b]
b[0].reparatur()"
grep -qx "options    root=PARTUUID=$uuid rw" "$e" || fail "neuer Eintrag fehlt oder falsch"
ok "fehlender Eintrag fuer den installierten Kernel wird neu angelegt"

n=$((n + 1))
mv "$e" "$t/esp/loader/entries/veyra-6.18.56-veyra4.conf"
mkdir -p "$t/esp/veyra/6.18.57-veyra1"; cp "$t/esp/veyra/6.18.56-veyra4/linux" "$t/esp/veyra/6.18.57-veyra1/linux"
sed 's/6.18.56-veyra4/6.18.57-veyra1/g' "$t/esp/loader/entries/veyra-6.18.56-veyra4.conf" > "$t/esp/loader/entries/veyra-6.18.57-veyra1.conf"
py "neu, alt = vr.zurueck(t + '/esp'); assert (neu, alt) == ('6.18.57-veyra1', '6.18.56-veyra4'), (neu, alt)"
[ -f "$t/esp/loader/entries/veyra-6.18.57-veyra1+0.conf" ] || fail "neuer Kernel nicht als schlecht markiert"
py "
try:
    vr.zurueck(t + '/esp'); raise SystemExit('zweites zurueck ohne Ausweichkernel angenommen')
except vr.Fehler: pass"
ok "kernel zurueck markiert den Standard-Kernel als schlecht, aber nie den letzten brauchbaren"

n=$((n + 1))
if python3 "$pkg/veyra-recovery" repariere /dev/vda --bestaetigt /dev/vdb 2> "$t/err"; then fail "falsche Bestaetigung angenommen"; fi
grep -q -e 'passt nicht' -e 'braucht root' "$t/err" || fail "falsche Meldung: $(cat "$t/err")"
python3 "$pkg/veyra-recovery" --help > "$t/hilfe"
grep -q 'repariere GERAET' "$t/hilfe" || fail "Hilfe unvollstaendig"
ok "Aufruf: Hilfe vollstaendig, falsche Bestaetigung abgelehnt"

echo "Alle $n Recovery-Tests bestanden."
