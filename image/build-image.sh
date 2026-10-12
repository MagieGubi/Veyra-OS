#!/usr/bin/env bash
# Phase 5: baut aus Basissystem und Veyra-Kernel ein bootfaehiges Festplattenabbild.
#
# Aufbau (GPT):
#   1  EFI-Systempartition (FAT32, 64 MiB): \EFI\BOOT\BOOTX64.EFI = Veyra-Kernel (EFI-Stub)
#   2  Root (ext4, Partitionsname veyra-root): das Basissystem aus Stufe 4b
# Kein Bootloader, keine Initramfs: die Firmware startet den Kernel direkt, der Kernel
# findet sein Root ueber root=PARTLABEL=veyra-root (eingebaute Kommandozeile).
#
# Aufruf (als root, braucht mkfs.ext4, mkfs.fat, mtools, sfdisk, zstd):
#   image/build-image.sh SYSTEM.tar.zst KERNEL-VERZ PAKET-VERZ AUSGABE.img
#   KERNEL-VERZ enthaelt vmlinuz-* und modules-*.tar.zst (Phase 4),
#   PAKET-VERZ zusaetzliche .vpkg-Dateien, die ins Abbild sollen (z. B. veyra-release).
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "build-image.sh braucht root" >&2; exit 1; }
[ $# -eq 4 ] || { sed -n '2,15p' "$0"; exit 1; }
system=$1 kdir=$2 pkgdir=$3 img=$4
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1767225600}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Das System-Archiv enthaelt den Baum unter veyra/ (so wurde es in Stufe 4 gepackt).
root=$work/veyra

echo ">> Basissystem auspacken"
zstd -q -dc "$system" | tar -xpf - -C "$work" --numeric-owner
[ -x "$root/usr/lib/systemd/systemd" ] || { echo "kein systemd im Basissystem" >&2; exit 1; }
rm -rf "$root/var/lib/veyra-stage"

echo ">> Kernelmodule und Zusatzpakete"
kernel=$(ls "$kdir"/vmlinuz-*)
kver=${kernel##*/vmlinuz-}
zstd -q -dc "$kdir/modules-$kver.tar.zst" | tar -xpf - -C "$root" --keep-directory-symlink
for p in "$pkgdir"/*.vpkg; do
  [ -e "$p" ] || continue
  echo "   $(basename "$p")"
  zstd -q -dc "$p" | tar -xpf - -C "$root" --strip-components=1 --keep-directory-symlink files
done

echo ">> Systemkonfiguration"
echo veyra > "$root/etc/hostname"
cat > "$root/etc/fstab" <<'FSTAB'
# Dateisystem          Ziel  Typ   Optionen  dump  fsck
PARTLABEL=veyra-root   /     ext4  defaults  1     1
FSTAB
echo 'LANG=C.UTF-8' > "$root/etc/locale.conf"
# Leere machine-id: jedes gestartete System erzeugt beim ersten Start seine eigene.
: > "$root/etc/machine-id"
# Entwicklungsabbild: root ohne Passwort an der Konsole. Nicht fuer echte Rechner gedacht.
sed -i 's/^root:[^:]*:/root::/' "$root/etc/shadow"
cat > "$root/etc/issue" <<'ISSUE'
Veyra OS Core 0.1 (Entwicklungsabbild) \l
Anmeldung: root, ohne Passwort.

ISSUE

echo ">> Root-Dateisystem (ext4)"
used_mib=$(( $(du -sm "$root" | cut -f1) ))
root_mib=$(( used_mib + used_mib / 4 + 256 ))
# Feste UUID und Hash-Seed, damit gleiche Eingaben ein gleiches Dateisystem ergeben.
E2FSPROGS_FAKE_TIME=$SOURCE_DATE_EPOCH mkfs.ext4 -q -L veyra-root -d "$root" \
  -U 5e7a0c0e-0000-4000-8000-000000000001 -E hash_seed=5e7a0c0e-0000-4000-8000-000000000002 \
  "$work/root.img" "${root_mib}M"

echo ">> EFI-Systempartition"
esp_mib=64
mkfs.fat -C -F 32 -n VEYRA-EFI -i 5E7A0C0E "$work/esp.img" $((esp_mib * 1024)) >/dev/null
mmd -i "$work/esp.img" ::/EFI ::/EFI/BOOT
mcopy -i "$work/esp.img" "$kernel" ::/EFI/BOOT/BOOTX64.EFI

echo ">> GPT-Abbild zusammensetzen"
total_mib=$(( 1 + esp_mib + root_mib + 1 ))
rm -f "$img"
truncate -s "${total_mib}M" "$img"
sfdisk -q "$img" <<SFDISK
label: gpt
label-id: 5E7A0C0E-0000-4000-8000-000000000000
start=1MiB, size=${esp_mib}MiB, type=U, name="EFI", uuid=5E7A0C0E-0000-4000-8000-0000000000E1
size=${root_mib}MiB, type=L, name="veyra-root", uuid=5E7A0C0E-0000-4000-8000-0000000000E2
SFDISK
dd if="$work/esp.img" of="$img" bs=1M seek=1 conv=notrunc status=none
dd if="$work/root.img" of="$img" bs=1M seek=$((1 + esp_mib)) conv=notrunc status=none
sfdisk -l "$img"
echo "Abbild fertig: $img (Kernel $kver)"
