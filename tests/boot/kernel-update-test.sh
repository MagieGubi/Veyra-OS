#!/usr/bin/env bash
# Tests fuer veyra-kernel-update (packages/base/veyra-boot) mit einer EFI-Partition als
# Verzeichnis. Den echten Rueckfall ueber den Boot-Zaehler prueft der CI-Job in QEMU.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
pkg=$here/packages/base/veyra-boot
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
ok() { echo "ok $n - $1"; }
ku() { python3 "$pkg/veyra-kernel-update" --esp "$t/esp" "$@"; }

n=$((n + 1))
grep -q "$(sha256sum "$pkg/veyra-kernel-update" | cut -d' ' -f1)" "$pkg/recipe.sh" \
  || fail "sha256sums in $pkg/recipe.sh passt nicht zu veyra-kernel-update"
ok "Rezept passt zum Programm"

# kernel DATEI INHALT: falscher Kernel mit MZ-Kopf, PE-Signatur und Linux-Boot-Header
kernel() {
  python3 - "$1" "$2" <<'PY'
import struct, sys
b = bytearray(2 << 20)
b[0:2] = b"MZ"; struct.pack_into("<I", b, 0x3C, 0x80); b[0x80:0x84] = b"PE\0\0"
b[0x202:0x206] = b"HdrS"; b[0x1000:0x1000 + len(sys.argv[2])] = sys.argv[2].encode()
open(sys.argv[1], "wb").write(b)
PY
}
mkdir -p "$t/esp/loader/entries" "$t/esp/veyra/6.18.56-veyra4"
kernel "$t/esp/veyra/6.18.56-veyra4/linux" alt
printf 'title      Veyra OS\nversion    6.18.56-veyra4\nsort-key   veyra\nlinux      /veyra/6.18.56-veyra4/linux\noptions    root=PARTUUID=1234 rw\n' \
  > "$t/esp/loader/entries/veyra-6.18.56-veyra4.conf"
kernel "$t/neu" neu

n=$((n + 1))
head -c 3000000 /dev/zero > "$t/kaputt"
if ku --gebootet 6.18.56-veyra4 installiere "$t/kaputt" 6.18.57-veyra1 2> "$t/err"; then fail "kaputter Kernel angenommen"; fi
grep -q 'MZ-Kopf fehlt' "$t/err" || fail "falsche Meldung: $(cat "$t/err")"
cp "$t/neu" "$t/ohnehdr" && python3 -c "import sys; b=bytearray(open(sys.argv[1],'rb').read()); b[0x202:0x206]=b'XXXX'; open(sys.argv[1],'wb').write(b)" "$t/ohnehdr"
if ku --gebootet 6.18.56-veyra4 installiere "$t/ohnehdr" 6.18.57-veyra1 2> "$t/err"; then fail "EFI-Programm ohne Linux-Header angenommen"; fi
grep -q 'HdrS fehlt' "$t/err" || fail "falsche Meldung: $(cat "$t/err")"
if ku --gebootet 6.18.56-veyra4 installiere "$t/neu" '../boese' 2> "$t/err"; then fail "Version mit Pfad angenommen"; fi
[ "$(ls "$t/esp/loader/entries")" = veyra-6.18.56-veyra4.conf ] || fail "ESP trotz Ablehnung veraendert"
ok "kaputte Kerneldatei, EFI-Programm ohne Linux-Header und Version mit Pfad abgelehnt, nichts geaendert"

n=$((n + 1))
ku --gebootet 6.18.56-veyra4 installiere "$t/neu" 6.18.57-veyra1 > "$t/out" || fail "installiere: $(cat "$t/out")"
e=$t/esp/loader/entries/veyra-6.18.57-veyra1+3.conf
[ -f "$e" ] || fail "Eintrag mit Boot-Zaehler fehlt: $(ls "$t/esp/loader/entries")"
grep -qx 'options    root=PARTUUID=1234 rw' "$e" || fail "Optionen nicht vom laufenden Eintrag uebernommen"
grep -qx 'linux      /veyra/6.18.57-veyra1/linux' "$e" || fail "Eintrag zeigt nicht auf den neuen Kernel"
cmp -s "$t/neu" "$t/esp/veyra/6.18.57-veyra1/linux" || fail "Kernel nicht kopiert"
[ -f "$t/esp/loader/entries/veyra-6.18.56-veyra4.conf" ] || fail "alter Eintrag entfernt"
[ -z "$(find "$t/esp" -name '*.neu')" ] || fail ".neu-Dateien liegen geblieben"
ku --gebootet 6.18.56-veyra4 liste > "$t/out"
head -1 "$t/out" | grep -q '^6.18.57-veyra1 .*ungeprueft, noch 3' || fail "liste: $(cat "$t/out")"
grep -q '^6.18.56-veyra4 .*gut.*laeuft' "$t/out" || fail "liste ohne laufenden Kernel: $(cat "$t/out")"
if ku --gebootet 6.18.56-veyra4 installiere "$t/neu" 6.18.57-veyra1 2> "$t/err"; then fail "doppelte Version angenommen"; fi
ok "neuer Kernel neben dem alten, Eintrag mit Boot-Zaehler und Optionen des laufenden Kernels"

n=$((n + 1))
# systemd-boot hat ihn dreimal erfolglos versucht: schlecht, der alte bleibt Standard.
mv "$e" "$t/esp/loader/entries/veyra-6.18.57-veyra1+0-3.conf"
ku --gebootet 6.18.56-veyra4 liste | grep -q '^6.18.57-veyra1 .*schlecht' || fail "schlechter Eintrag nicht erkannt"
if ku --gebootet 6.18.56-veyra4 entferne 6.18.56-veyra4 2> "$t/err"; then fail "laufender Kernel entfernt"; fi
ku --gebootet 6.18.56-veyra4 entferne 6.18.57-veyra1 > /dev/null || fail "schlechten Kernel entfernen"
[ ! -e "$t/esp/veyra/6.18.57-veyra1" ] || fail "Kernel-Verzeichnis nicht entfernt"
ok "schlechter Kernel (Zaehler 0) erkannt und entfernt; laufender Kernel bleibt"

n=$((n + 1))
# Drei gute Kernel nacheinander: die zwei neuesten guten bleiben, der laufende immer.
for v in 6.18.58-veyra1 6.18.59-veyra1; do
  kernel "$t/k-$v" "$v"
  ku --gebootet 6.18.56-veyra4 installiere "$t/k-$v" "$v" > /dev/null
  mv "$t/esp/loader/entries/veyra-$v+3.conf" "$t/esp/loader/entries/veyra-$v.conf"   # bless-boot
done
ku --gebootet 6.18.59-veyra1 installiere "$t/neu" 6.18.60-veyra1 > "$t/out"
find "$t/esp/loader/entries" -mindepth 1 -printf "%f\n" | sort > "$t/ls"
printf '%s\n' veyra-6.18.58-veyra1.conf veyra-6.18.59-veyra1.conf veyra-6.18.60-veyra1+3.conf > "$t/soll"
diff "$t/soll" "$t/ls" || fail "falsch aufgeraeumt"
[ ! -e "$t/esp/veyra/6.18.56-veyra4" ] || fail "Kernel des entfernten Eintrags liegt noch"
grep -q 'Alten Kernel 6.18.56-veyra4 entfernt' "$t/out" || fail "Aufraeumen nicht gemeldet"
ok "Aufraeumen: zwei neueste gute Kernel und der neue ungepruefte bleiben"

echo "Alle $n Kernel-Update-Tests bestanden."
