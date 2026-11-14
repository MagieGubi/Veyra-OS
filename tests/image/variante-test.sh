#!/usr/bin/env bash
# Tests fuer die Abbild-Varianten von image/build-image.sh (dev und test) mit einem
# kuenstlichen Mini-Basissystem statt Stufe 4b: prueft, was im Root-Dateisystem landet
# (root-Passwort, Variante, Ersteinrichtung, su nur fuer wheel). Bootet nichts; das macht
# der Boot-Test im CI mit dem echten System.
# Braucht root (build-image.sh), mkfs.ext4, debugfs, mkfs.fat, mtools, sfdisk, zstd.
# Schreibt nur in ein temporaeres Verzeichnis.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
[ "$(id -u)" = 0 ] || { echo "variante-test.sh braucht root (sudo)" >&2; exit 1; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
ok() { echo "ok $n - $1"; }

# Mini-Basissystem in der Form von Stufe 4b (Baum unter veyra/)
s=$t/sys/veyra
mkdir -p "$s/usr/lib/systemd" "$s/etc" "$s/var/lib/veyra-stage" "$s/tmp"
printf '#!/bin/sh\n' > "$s/usr/lib/systemd/systemd"; chmod 755 "$s/usr/lib/systemd/systemd"
printf 'root:x:0:0:root:/root:/bin/bash\n' > "$s/etc/passwd"
# shellcheck disable=SC2016 # Hash-Platzhalter, $ ist hier woertlich gemeint
printf 'root:$6$abc$def:20000:0:99999:7:::\nnobody:!:20000::::::\n' > "$s/etc/shadow"; chmod 600 "$s/etc/shadow"
printf 'root:x:0:\nwheel:x:97:\n' > "$s/etc/group"
printf 'UID_MIN 1000\n#SU_WHEEL_ONLY no\n' > "$s/etc/login.defs"
tar -C "$t/sys" -cf - veyra | zstd -q -o "$t/system.tar.zst"
# Kernel-Platzhalter und leeres Modularchiv
mkdir -p "$t/k"
echo kernel > "$t/k/vmlinuz-6.18.56-veyra2"
tar -cf - -T /dev/null | zstd -q -o "$t/k/modules-6.18.56-veyra2.tar.zst"
# Zusatzpakete: veyra-konten (ohne Basis-Datenbank nur ausgepackt)
mkdir -p "$t/extra"
"$here/build/scripts/vpkg-build" --srcdir "$here" --outdir "$t/extra" "$here/packages/base/veyra-konten" >/dev/null

# baue VARIANTE AUSGABE [PAKETVERZ]
baue() { VARIANTE=$1 "$here/image/build-image.sh" "$t/system.tar.zst" "$t/k" "${3:-$t/extra}" "$t/$2" > "$t/$2.log" 2>&1; }
# lies ABBILD PFAD: Datei aus dem Root-Dateisystem (Partition 2) lesen
lies() {
  local start
  start=$(sfdisk -d "$t/$1" | awk -F'[=,]' '/name="veyra-root"/ {gsub(/ /, "", $2); print $2}')
  dd if="$t/$1" of="$t/root.ext4" bs=512 skip="$start" status=none
  debugfs -R "cat $2" "$t/root.ext4" 2>/dev/null
}

n=$((n + 1))
baue dev dev.img || { cat "$t/dev.img.log"; fail "dev-Abbild nicht gebaut"; }
[ "$(lies dev.img /etc/veyra/variante)" = dev ] || fail "Variante dev fehlt"
lies dev.img /etc/shadow | grep -q '^root::' || fail "root im dev-Abbild nicht ohne Passwort"
lies dev.img /etc/issue | grep -q 'Entwicklungsabbild' || fail "issue nennt das Entwicklungsabbild nicht"
lies dev.img /etc/hostname >/dev/null
if debugfs -R 'stat /etc/veyra/einrichtung-noetig' "$t/root.ext4" 2>/dev/null | grep -q Inode; then
  fail "dev-Abbild verlangt Ersteinrichtung"
fi
ok "dev-Abbild: root ohne Passwort, Variante dev, keine Ersteinrichtung"

n=$((n + 1))
baue test test.img || { cat "$t/test.img.log"; fail "test-Abbild nicht gebaut"; }
[ "$(lies test.img /etc/veyra/variante)" = test ] || fail "Variante test fehlt"
lies test.img /etc/shadow | grep -q '^root:!\*:' || fail "root im Testabbild nicht gesperrt"
debugfs -R 'stat /etc/veyra/einrichtung-noetig' "$t/root.ext4" 2>/dev/null | grep -q 'Inode' || fail "Ersteinrichtung nicht vorgemerkt"
lies test.img /etc/login.defs | grep -qx 'SU_WHEEL_ONLY yes' || fail "SU_WHEEL_ONLY nicht gesetzt"
lies test.img /etc/issue | grep -q 'Testabbild' || fail "issue nennt das Testabbild nicht"
debugfs -R 'stat /usr/bin/veyra-einrichtung' "$t/root.ext4" 2>/dev/null | grep -q 'Inode' || fail "veyra-einrichtung fehlt"
debugfs -R 'stat /etc/shadow' "$t/root.ext4" 2>/dev/null | grep -q 'Mode:  0600' || fail "Rechte von shadow im Abbild falsch"
ok "Testabbild: root gesperrt, Ersteinrichtung vorgemerkt, su nur fuer wheel, shadow 0600"

n=$((n + 1))
mkdir -p "$t/leer"
if baue test ohne.img "$t/leer"; then fail "Testabbild ohne veyra-konten gebaut"; fi
grep -q 'braucht das Paket veyra-konten' "$t/ohne.img.log" || { cat "$t/ohne.img.log"; fail "Meldung fehlt"; }
ok "Testabbild ohne veyra-konten wird abgelehnt"

n=$((n + 1))
if VARIANTE=prod "$here/image/build-image.sh" "$t/system.tar.zst" "$t/k" "$t/extra" "$t/x.img" > "$t/x.log" 2>&1; then
  fail "unbekannte Variante angenommen"
fi
grep -q 'VARIANTE muss dev oder test sein' "$t/x.log" || fail "Meldung zur Variante fehlt"
ok "unbekannte Variante wird abgelehnt"

echo "Alle $n Abbild-Tests bestanden."
