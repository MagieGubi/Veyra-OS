#!/usr/bin/env bash
# Tests fuer den Installer (packages/base/veyra-installer) mit einem kuenstlichen
# Quellsystem und virtuellen Platten (sparse Dateien in einem temporaeren Verzeichnis).
# Kein echter Datentraeger wird angefasst: jedes Ziel ist eine hier angelegte Datei.
# Braucht root (losetup, mount), sfdisk, blkid, mkfs.ext4, debugfs, fsck.fat, mtools, python3.
# Den Boot des installierten Systems prueft der CI-Job "Abbild" in QEMU.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
pkg=$here/packages/base/veyra-installer
inst=$pkg/veyra-install
[ "$(id -u)" = 0 ] || { echo "installer-test.sh braucht root (sudo)" >&2; exit 1; }
t=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] || rm -rf "$t"' EXIT
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
ok() { echo "ok $n - $1"; }

n=$((n + 1))
for f in veyra-install veyra_install.py veyra_fat.py; do
  grep -q "$(sha256sum "$pkg/$f" | cut -d' ' -f1)" "$pkg/recipe.sh" \
    || fail "sha256sums in $pkg/recipe.sh passt nicht zu $f"
done
ok "Rezept passt zu den Programmen"

# FAT32 allein: Dateisystem pruefen, Datei unveraendert zuruecklesen
n=$((n + 1))
truncate -s 600M "$t/fat.img"
head -c 3000000 /dev/urandom > "$t/k.bin"
python3 -c "
import sys; sys.path.insert(0, '$pkg'); import veyra_fat as f
f.schreibe_fat32('$t/fat.img', 1 << 20, 512 << 20, {'EFI/BOOT/BOOTX64.EFI': open('$t/k.bin', 'rb').read(), 'LIESMICH.TXT': b'x'})"
dd if="$t/fat.img" of="$t/esp.part" bs=1M skip=1 count=512 status=none
fsck.fat -n "$t/esp.part" > "$t/fsck.log" 2>&1 || { cat "$t/fsck.log"; fail "fsck.fat meldet Fehler"; }
mcopy -n -i "$t/esp.part" ::/EFI/BOOT/BOOTX64.EFI "$t/k2.bin"
cmp -s "$t/k.bin" "$t/k2.bin" || fail "BOOTX64.EFI weicht ab"
file -s "$t/esp.part" | grep -q 'FAT (32 bit)' || fail "kein FAT32: $(file -s "$t/esp.part")"
rm -f "$t/fat.img" "$t/esp.part" "$t/k2.bin"
ok "FAT32 fuer die EFI-Systempartition (fsck.fat sauber, Datei gleich)"

n=$((n + 1))
truncate -s 20M "$t/klein.img"
if python3 -c "
import sys; sys.path.insert(0, '$pkg'); import veyra_fat as f
f.schreibe_fat32('$t/klein.img', 0, 16 << 20, {'A.TXT': b'x'})" 2> "$t/klein.log"; then
  fail "FAT32 auf 16 MiB angenommen"
fi
grep -q 'zu klein fuer FAT32' "$t/klein.log" || fail "falsche Meldung: $(cat "$t/klein.log")"
ok "zu kleine EFI-Partition abgelehnt"

# Kuenstliches Quellsystem (wie das Live-System): Konten, VPKG mit Selbsttest-Paket, Kernel
q=$t/quelle
mkdir -p "$q/usr/lib/systemd" "$q/usr/bin" "$q/etc/veyra" "$q/var/lib/vpkg" "$q/root" \
  "$q/usr/lib/modules/6.18.56-veyra2" "$q/usr/lib/veyra/selftest" "$q/proc" "$q/sys" "$q/dev" "$q/run"
mkdir -p "$q/tmp" && chmod 1777 "$q/tmp"
printf '#!/bin/sh\n' > "$q/usr/lib/systemd/systemd"; chmod 755 "$q/usr/lib/systemd/systemd"
cp "$here/packages/base/vpkg/vpkg" "$q/usr/bin/vpkg"
cp "$here/packages/base/veyra-konten/veyra-einrichtung" "$here/packages/base/veyra-konten/veyra-kontencheck" "$q/usr/bin/"
printf 'root:x:0:0:root:/root:/bin/bash\nnobody:x:65534:65534:nobody:/:/usr/bin/false\n' > "$q/etc/passwd"
printf 'root::20000:0:99999:7:::\nnobody:!:20000::::::\n' > "$q/etc/shadow"
printf 'root:x:0:\nwheel:x:97:\nnogroup:x:65534:\n' > "$q/etc/group"
printf 'root:::\nwheel:!::\nnogroup:!::\n' > "$q/etc/gshadow"
chmod 600 "$q/etc/shadow" "$q/etc/gshadow"
printf 'UID_MIN 1000\n#SU_WHEEL_ONLY no\n' > "$q/etc/login.defs"
echo dev > "$q/etc/veyra/variante"
printf 'PARTLABEL=veyra-daten /mnt/daten vfat defaults 0 0\n' > "$q/etc/fstab"
head -c 2000000 /dev/urandom > "$q/usr/lib/modules/6.18.56-veyra2/vmlinuz"
echo demo > "$q/usr/lib/veyra/selftest/vpkg-demo-1.0-1-x86_64.vpkg"
mkdir -p "$t/st"
cat > "$t/st/recipe.sh" <<'R'
pkgname=veyra-selftest
pkgver=0.6
pkgrel=1
license=MIT
package() { install -d "$pkgdir/usr/lib/veyra"; echo selbsttest > "$pkgdir/usr/lib/veyra/selftest.sh"; }
R
"$here/build/scripts/vpkg-build" --srcdir "$t/st" --outdir "$t/st" "$t/st" >/dev/null
python3 "$q/usr/bin/vpkg" --root "$q" install --no-deps "$t"/st/veyra-selftest-*.vpkg >/dev/null

# leere virtuelle Platte (sparse Datei, 3 GiB)
platte() { rm -f "$t/$1"; truncate -s "${2:-3G}" "$t/$1"; }
# lies ABBILD PFAD: Datei aus der Root-Partition (Partition 2)
lies() {
  local start
  start=$(sfdisk -J "$t/$1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["partitiontable"]["partitions"][1]["start"])')
  dd if="$t/$1" of="$t/root.ext4" bs=512 skip="$start" status=none
  debugfs -R "cat $2" "$t/root.ext4" 2>/dev/null
}
gibt() { debugfs -R "stat $1" "$t/root.ext4" 2>/dev/null | grep -q '^Inode:'; }

n=$((n + 1)); platte leer.img
"$inst" pruefe "$t/leer.img" --quelle "$q" > "$t/p.log" 2>&1 || { cat "$t/p.log"; fail "pruefe auf leerer Platte schlug fehl"; }
{ grep -q 'leer' "$t/p.log" && grep -q '"veyra-root": Veyra-Root (ext4)' "$t/p.log" && grep -q '"veyra-efi"' "$t/p.log"; } \
  || { cat "$t/p.log"; fail "Plan unvollstaendig"; }
ok "pruefe: leere Platte, Plan mit EFI- und Root-Partition"

n=$((n + 1)); platte winzig.img 1G
if "$inst" pruefe "$t/winzig.img" --quelle "$q" > "$t/p.log" 2>&1; then fail "zu kleine Platte angenommen"; fi
grep -q 'zu klein' "$t/p.log" || { cat "$t/p.log"; fail "keine Meldung 'zu klein'"; }
ok "zu kleine Platte abgelehnt"

# Platte mit vorhandenem System: Partitionstabelle und ext4 mit Daten
n=$((n + 1)); platte alt.img
printf 'label: gpt\nstart=1MiB, size=200MiB, type=L, name="daten"\n' | sfdisk -q "$t/alt.img"
mkdir -p "$t/altinhalt" && echo wichtig > "$t/altinhalt/brief.txt"
mkfs.ext4 -q -L meine-daten -d "$t/altinhalt" -E offset=$((1 << 20)) "$t/alt.img" 200M
sha=$(sha256sum < "$t/alt.img")
"$inst" pruefe "$t/alt.img" --quelle "$q" > "$t/p.log" 2>&1 || { cat "$t/p.log"; fail "pruefe schlug fehl"; }
grep -q 'Linux (ext4), Bezeichnung meine-daten' "$t/p.log" || { cat "$t/p.log"; fail "vorhandenes System nicht erkannt"; }
ok "vorhandenes System erkannt (Linux, ext4, Bezeichnung)"

n=$((n + 1))
if echo falsch | "$inst" installiere "$t/alt.img" --quelle "$q" > "$t/i.log" 2>&1; then fail "ohne Bestaetigung installiert"; fi
grep -q 'Nicht bestaetigt' "$t/i.log" || { cat "$t/i.log"; fail "keine Meldung 'Nicht bestaetigt'"; }
[ "$(sha256sum < "$t/alt.img")" = "$sha" ] || fail "Platte trotz fehlender Bestaetigung veraendert"
if "$inst" installiere "$t/alt.img" --quelle "$q" < /dev/null > "$t/i.log" 2>&1; then fail "ohne Eingabe installiert"; fi
[ "$(sha256sum < "$t/alt.img")" = "$sha" ] || fail "Platte ohne Eingabe veraendert"
if "$inst" installiere "$t/alt.img" --quelle "$q" --bestaetigt "$t/leer.img" > "$t/i.log" 2>&1; then fail "falsches --bestaetigt angenommen"; fi
[ "$(sha256sum < "$t/alt.img")" = "$sha" ] || fail "Platte mit falschem --bestaetigt veraendert"
ok "ohne passende Bestaetigung wird nichts geschrieben (falscher Name, keine Eingabe, falsches --bestaetigt)"

n=$((n + 1))
loop=$(losetup --find --show "$t/alt.img")
if "$inst" pruefe "$t/alt.img" --quelle "$q" > "$t/p.log" 2>&1; then losetup -d "$loop"; fail "gebundene Datei angenommen"; fi
losetup -d "$loop"
grep -q 'in Benutzung' "$t/p.log" || { cat "$t/p.log"; fail "keine Meldung 'in Benutzung'"; }
ok "Ziel in Benutzung (an Loop-Geraet gebunden) abgelehnt"

n=$((n + 1))
mkdir -p "$t/kaputt" && cp -a "$q/." "$t/kaputt/" && rm "$t/kaputt/usr/bin/veyra-einrichtung"
if "$inst" installiere "$t/alt.img" --quelle "$t/kaputt" --bestaetigt "$t/alt.img" > "$t/i.log" 2>&1; then fail "unvollstaendige Quelle angenommen"; fi
grep -q 'veyra-einrichtung' "$t/i.log" || { cat "$t/i.log"; fail "fehlendes Programm nicht genannt"; }
[ "$(sha256sum < "$t/alt.img")" = "$sha" ] || fail "Platte trotz unvollstaendiger Quelle veraendert"
ok "unvollstaendiges Quellsystem abgelehnt, bevor etwas geschrieben wird"

n=$((n + 1))
echo "$t/alt.img" | "$inst" installiere "$t/alt.img" --quelle "$q" --hostname testrechner > "$t/i.log" 2>&1 \
  || { cat "$t/i.log"; fail "Installation schlug fehl"; }
sfdisk -d "$t/alt.img" > "$t/tab"
{ grep -q 'name="veyra-efi"' "$t/tab" && grep -q 'name="veyra-root"' "$t/tab" && grep -q 'label: gpt' "$t/tab"; } \
  || { cat "$t/tab"; fail "Partitionstabelle falsch"; }
[ "$(grep -c '^/' "$t/tab")" = 2 ] || fail "nicht genau zwei Partitionen"
grep -q 'type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B' "$t/tab" || fail "Partition 1 ist keine EFI-Systempartition"
ok "Installation mit eingetipptem Geraetenamen: GPT mit veyra-efi und veyra-root"

n=$((n + 1))
start=$(sfdisk -J "$t/alt.img" | python3 -c 'import json,sys; p=json.load(sys.stdin)["partitiontable"]["partitions"][0]; print(p["start"], p["size"])')
read -r s1 z1 <<<"$start"
dd if="$t/alt.img" of="$t/esp.part" bs=512 skip="$s1" count="$z1" status=none
fsck.fat -n "$t/esp.part" > "$t/fsck.log" 2>&1 || { cat "$t/fsck.log"; fail "EFI-Partition fehlerhaft"; }
mcopy -n -i "$t/esp.part" ::/EFI/BOOT/BOOTX64.EFI "$t/k2.bin"
cmp -s "$t/k2.bin" "$q/usr/lib/modules/6.18.56-veyra2/vmlinuz" || fail "BOOTX64.EFI ist nicht der Kernel der Quelle"
ok "EFI-Partition: FAT32 sauber, BOOTX64.EFI ist der Kernel des Quellsystems"

n=$((n + 1))
[ "$(lies alt.img /etc/veyra/variante)" = system ] || fail "Variante nicht 'system'"
lies alt.img /etc/shadow | grep -q '^root:!\*:' || fail "root nicht gesperrt: $(lies alt.img /etc/shadow | head -1)"
gibt /etc/veyra/einrichtung-noetig || fail "Ersteinrichtung nicht vorgemerkt"
lies alt.img /etc/login.defs | grep -q '^SU_WHEEL_ONLY yes' || fail "SU_WHEEL_ONLY fehlt"
lies alt.img /etc/fstab | grep -q '^PARTLABEL=veyra-root ' || fail "fstab ohne Root"
lies alt.img /etc/fstab | grep -q 'veyra-daten' && fail "fstab enthaelt noch die Datenpartition des Abbilds"
[ "$(lies alt.img /etc/hostname)" = testrechner ] || fail "Rechnername falsch"
[ -z "$(lies alt.img /etc/machine-id)" ] || fail "machine-id nicht leer"
gibt /brief.txt && fail "alte Daten im neuen Dateisystem"
ok "installiertes System: Variante system, root gesperrt bis zur Ersteinrichtung, su nur wheel, eigene fstab"

n=$((n + 1))
gibt /var/lib/vpkg/installed/veyra-selftest && fail "Selbsttest-Paket noch installiert"
gibt /usr/lib/veyra/selftest.sh && fail "Datei des Selbsttests noch da"
gibt /usr/lib/veyra/selftest && fail "Testpakete des Selbsttests noch da"
grep -q 'vpkg remove veyra-selftest' "$t/i.log" || fail "Entfernen nicht gemeldet"
ok "Selbsttest per vpkg entfernt"

n=$((n + 1)); platte st.img
"$inst" installiere "$t/st.img" --quelle "$q" --mit-selbsttest --bestaetigt "$t/st.img" > "$t/i.log" 2>&1 \
  || { cat "$t/i.log"; fail "Installation mit Selbsttest schlug fehl"; }
lies st.img /etc/hostname > /dev/null
gibt /var/lib/vpkg/installed/veyra-selftest || fail "Selbsttest fehlt trotz --mit-selbsttest"
{ grep -q 'Pruefen: vpkg check' "$t/i.log" && grep -q 'Pruefen: veyra-kontencheck' "$t/i.log"; } || fail "Pruefungen nicht gelaufen"
ok "--mit-selbsttest behaelt den Selbsttest; vpkg check und veyra-kontencheck liefen"

n=$((n + 1))
"$inst" pruefe "$t/st.img" --quelle "$q" > "$t/p.log" 2>&1 || true
grep -q 'Veyra OS' "$t/p.log" || { cat "$t/p.log"; fail "installiertes Veyra nicht erkannt"; }
ok "pruefe erkennt ein installiertes Veyra"
echo "Alle $n Installer-Tests bestanden."
