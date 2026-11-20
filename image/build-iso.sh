#!/usr/bin/env bash
# Baut aus dem fertigen Festplattenabbild die Live-ISO von Veyra (startet per UEFI von CD,
# DVD oder USB-Stick, in VirtualBox ohne Installation).
#
# Aufbau der ISO:
#   /veyra/root.sfs   das Root-Dateisystem des Abbilds als SquashFS (zstd)
#   EFI-Partition     \EFI\BOOT\BOOTX64.EFI = Live-Kernel mit eingebauter Initramfs
#                     (kernel/live/init.c: sucht das Medium, haengt root.sfs ein, legt ein
#                     beschreibbares Overlay im Arbeitsspeicher darueber, startet systemd)
#
# Aufruf (als root, braucht losetup, sfdisk, python3, mksquashfs, mkfs.fat, mtools, xorriso):
#   image/build-iso.sh ABBILD.img KERNEL-VERZ AUSGABE.iso
#   ABBILD.img aus build-image.sh (wird dabei veraendert: fstab fuer den Live-Betrieb),
#   KERNEL-VERZ enthaelt vmlinuz-live-* (Phase 4).
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "build-iso.sh braucht root" >&2; exit 1; }
[ $# -eq 3 ] || { sed -n '2,16p' "$0"; exit 1; }
img=$1 kdir=$2 iso=$3
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1767225600}

kernel=$(find "$kdir" -maxdepth 1 -name 'vmlinuz-live-*')
work=$(mktemp -d)
loop=""
cleanup() {
  mountpoint -q "$work/root" && umount "$work/root"
  [ -n "$loop" ] && losetup -d "$loop"
  rm -rf "$work"
}
trap cleanup EXIT

echo ">> Root-Partition des Abbilds einhaengen"
# Ueber Start und Groesse aus der Partitionstabelle (ohne --partscan, das braucht udev).
read -r start size < <(sfdisk -J "$img" | python3 -c '
import json, sys
p = json.load(sys.stdin)["partitiontable"]["partitions"][1]
print(p["start"] * 512, p["size"] * 512)')
loop=$(losetup --find --show --offset "$start" --sizelimit "$size" "$img")
mkdir -p "$work/root"
mount -t ext4 "$loop" "$work/root"

echo ">> Anpassungen fuer den Live-Betrieb"
cat > "$work/root/etc/fstab" <<'FSTAB'
# Veyra Live: "/" ist ein Overlay aus /veyra/root.sfs (nur lesen) und dem Arbeitsspeicher.
# Aenderungen gehen beim Ausschalten verloren.
FSTAB
cat > "$work/root/etc/issue" <<'ISSUE'
Veyra OS 0.6 Live (Entwicklungsabbild) \l
Anmeldung: root, ohne Passwort. Aenderungen gehen beim Ausschalten verloren.

ISSUE
# Medium, SquashFS und RAM-Schicht tragen das laufende Root-Dateisystem (eingehaengt von
# kernel/live/init.c). systemd darf sie beim Herunterfahren nicht einzeln aushaengen (das
# scheitert, das Medium ist belegt): ohne Standard-Abhaengigkeiten entfaellt der Konflikt
# mit umount.target, sie bleiben bis zum Ausschalten stehen wie "/" selbst.
for m in medium sfs rw; do
  d="$work/root/etc/systemd/system/run-veyra\\x2dlive-$m.mount.d"
  mkdir -p "$d"
  printf '[Unit]\nDefaultDependencies=no\n' > "$d/live.conf"
done

echo ">> SquashFS (Zeitstempel aus SOURCE_DATE_EPOCH, das mksquashfs selbst auswertet)"
mkdir -p "$work/iso/veyra"
mksquashfs "$work/root" "$work/iso/veyra/root.sfs" -comp zstd -Xcompression-level 15 \
  -noappend -no-progress \
  -e lost+found
umount "$work/root"
losetup -d "$loop"
loop=""
cat > "$work/iso/veyra/LIESMICH.txt" <<'TXT'
Veyra OS 0.6 Live
Startet per UEFI (in VirtualBox: EFI aktivieren). Anmeldung: root, ohne Passwort.
Das System laeuft komplett im Arbeitsspeicher, es wird nichts installiert.
TXT

echo ">> EFI-Bootabbild (Live-Kernel als BOOTX64.EFI)"
esp_kib=$(( $(stat -c %s "$kernel") / 1024 + 2048 ))
mkfs.fat -C -n VEYRA-LIVE -i 5E7A0C0F "$work/efiboot.img" "$esp_kib" >/dev/null
mmd -i "$work/efiboot.img" ::/EFI ::/EFI/BOOT
mcopy -i "$work/efiboot.img" "$kernel" ::/EFI/BOOT/BOOTX64.EFI

echo ">> ISO zusammensetzen"
find "$work/iso" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
rm -f "$iso"
xorriso -as mkisofs -iso-level 3 -rational-rock -joliet \
  -volid VEYRA_LIVE -appid "Veyra OS 0.6 Live" -publisher "Veyra OS" \
  -partition_offset 16 \
  -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$work/efiboot.img" \
  -appended_part_as_gpt \
  -e --interval:appended_partition_2:all:: -no-emul-boot \
  -output "$iso" "$work/iso"
ls -l "$iso"
echo "ISO fertig: $iso (Kernel $(basename "$kernel"))"
