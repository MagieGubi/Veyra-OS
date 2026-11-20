#!/usr/bin/env bash
# Phase 5: baut aus Basissystem und Veyra-Kernel ein bootfaehiges Festplattenabbild.
#
# Aufbau (GPT):
#   1  EFI-Systempartition (FAT32, 64 MiB): \EFI\BOOT\BOOTX64.EFI = Veyra-Kernel (EFI-Stub)
#   2  Root (ext4, Partitionsname veyra-root): das Basissystem aus Stufe 4b
#   3  Daten (FAT, Partitionsname veyra-daten, 32 MiB): Messwerte und Kernel-Log des
#      Selbsttests, unter Windows als normales Laufwerk lesbar (Start vom USB-Stick)
# Kein Bootloader, keine Initramfs: die Firmware startet den Kernel direkt, der Kernel
# findet sein Root ueber root=PARTLABEL=veyra-root (eingebaute Kommandozeile).
#
# Variante (Umgebungsvariable VARIANTE):
#   dev   Entwicklungsabbild fuer CI und VM: root ohne Passwort an der Konsole (Standard)
#   test  Testabbild fuer echte Rechner: root gesperrt, bis die Ersteinrichtung an
#         Konsole 1 ein Passwort setzt (Paket veyra-konten muss in PAKET-VERZ liegen);
#         su nur fuer Mitglieder der Gruppe wheel
# Die Variante steht im Abbild in /etc/veyra/variante und in /etc/issue.
#
# Aufruf (als root, braucht mkfs.ext4, mkfs.fat, mtools, sfdisk, zstd, python3 >= 3.11):
#   image/build-image.sh SYSTEM.tar.zst KERNEL-VERZ PAKET-VERZ AUSGABE.img [BASIS-VERZ]
#   KERNEL-VERZ enthaelt vmlinuz-* und modules-*.tar.zst (Phase 4),
#   PAKET-VERZ zusaetzliche .vpkg-Dateien, die mit VPKG ins Abbild installiert werden
#     (z. B. veyra-release, vpkg); liegt darin ein Ordner selftest/, kommt sein Inhalt
#     nach /usr/lib/veyra/selftest (Testpakete fuer den Selbsttest); liegt darin
#     veyra-keyring-*.vpkg, wird es zuerst installiert (Signaturpruefung ab dann Pflicht),
#   BASIS-VERZ die .vpkg-Dateien des Basissystems (Stufe 4b); sie werden in die
#     VPKG-Datenbank des Abbilds eingetragen (vpkg register).
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "build-image.sh braucht root" >&2; exit 1; }
[ $# -eq 4 ] || [ $# -eq 5 ] || { sed -n '2,20p' "$0"; exit 1; }
system=$1 kdir=$2 pkgdir=$3 img=$4 basedir=${5:-}
variante=${VARIANTE:-dev}
case $variante in dev|test) ;; *) echo "VARIANTE muss dev oder test sein, nicht '$variante'" >&2; exit 1 ;; esac
vpkg=$(cd "$(dirname "$0")/.." && pwd)/packages/base/vpkg/vpkg
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
kernel=$(find "$kdir" -maxdepth 1 -name 'vmlinuz-*' ! -name 'vmlinuz-live-*')
kver=${kernel##*/vmlinuz-}
zstd -q -dc "$kdir/modules-$kver.tar.zst" | tar -xpf - -C "$root" --keep-directory-symlink
# Kernel auch ins System legen: der Installer (veyra-install) schreibt ihn von dort auf die
# EFI-Systempartition des Ziels (die Live-ISO selbst startet einen eigenen Live-Kernel).
install -Dm644 "$kernel" "$root/usr/lib/modules/$kver/vmlinuz"
# Paketschluessel zuerst: danach verlangt VPKG fuer jedes weitere Paket eine gueltige
# Signatur, auch fuer die Basispakete beim Eintragen.
mapfile -t keyring < <(find "$pkgdir" -maxdepth 1 -name 'veyra-keyring-*.vpkg')
if [ "${#keyring[@]}" -gt 0 ]; then
  echo ">> Paketschluessel (veyra-keyring)"
  python3 "$vpkg" --root "$root" install --no-deps "${keyring[@]}"
fi
if [ -n "$basedir" ]; then
  echo ">> Basispakete in die VPKG-Datenbank eintragen"
  mapfile -t base < <(find "$basedir" -name '*.vpkg' | LC_ALL=C sort)
  [ "${#base[@]}" -gt 0 ] || { echo "keine Basispakete in $basedir" >&2; exit 1; }
  python3 "$vpkg" --root "$root" register "${base[@]}"
fi
mapfile -t extra < <(find "$pkgdir" -maxdepth 1 -name '*.vpkg' ! -name 'veyra-keyring-*' | LC_ALL=C sort)
if [ "${#extra[@]}" -gt 0 ]; then
  if [ -n "$basedir" ]; then
    python3 "$vpkg" --root "$root" install "${extra[@]}"
  else
    # Ohne Datenbank des Basissystems nur auspacken (Abhaengigkeiten nicht pruefbar).
    for p in "${extra[@]}"; do
      echo "   $(basename "$p")"
      zstd -q -dc "$p" | tar -xpf - -C "$root" --strip-components=1 --keep-directory-symlink files
    done
  fi
fi
if [ -d "$pkgdir/selftest" ]; then
  install -d "$root/usr/lib/veyra/selftest"
  cp "$pkgdir"/selftest/* "$root/usr/lib/veyra/selftest/"
fi

echo ">> Systemkonfiguration"
echo veyra > "$root/etc/hostname"
cat > "$root/etc/fstab" <<'FSTAB'
# Dateisystem          Ziel  Typ   Optionen  dump  fsck
PARTLABEL=veyra-root   /     ext4  defaults  1     1
PARTLABEL=veyra-daten  /mnt/daten  vfat  defaults,nofail,umask=022  0  0
FSTAB
install -d "$root/mnt/daten"
echo 'LANG=C.UTF-8' > "$root/etc/locale.conf"
# Leere machine-id: jedes gestartete System erzeugt beim ersten Start seine eigene.
: > "$root/etc/machine-id"
install -d "$root/etc/veyra"
echo "$variante" > "$root/etc/veyra/variante"
if [ "$variante" = dev ]; then
  # Entwicklungsabbild: root ohne Passwort an der Konsole. Nicht fuer echte Rechner gedacht.
  sed -i 's/^root:[^:]*:/root::/' "$root/etc/shadow"
  cat > "$root/etc/issue" <<'ISSUE'
Veyra OS 0.6 (Entwicklungsabbild, nur fuer VM und CI) \l
Anmeldung: root, ohne Passwort.

ISSUE
else
  [ -x "$root/usr/bin/veyra-einrichtung" ] \
    || { echo "VARIANTE=test braucht das Paket veyra-konten in $pkgdir" >&2; exit 1; }
  # Testabbild: root gesperrt (kein gueltiger Hash), bis veyra-einrichtung ein Passwort setzt.
  sed -i 's/^root:[^:]*:/root:!*:/' "$root/etc/shadow"
  if awk -F: '$2 == "" {f = 1} END {exit !f}' "$root/etc/shadow"; then
    echo "Konto ohne Passwort im Testabbild: $(awk -F: '$2 == "" {print $1}' "$root/etc/shadow")" >&2; exit 1
  fi
  touch "$root/etc/veyra/einrichtung-noetig"
  # su nur fuer die Gruppe wheel (shadow ohne PAM liest das aus login.defs).
  if grep -qE '^#?[[:space:]]*SU_WHEEL_ONLY' "$root/etc/login.defs"; then
    sed -i -E 's/^#?[[:space:]]*SU_WHEEL_ONLY.*/SU_WHEEL_ONLY yes/' "$root/etc/login.defs"
  else
    echo 'SU_WHEEL_ONLY yes' >> "$root/etc/login.defs"
  fi
  cat > "$root/etc/issue" <<'ISSUE'
Veyra OS 0.6 (Testabbild) \l
root ist gesperrt, bis die Ersteinrichtung an Konsole 1 ein Passwort gesetzt hat.

ISSUE
fi

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

echo ">> Datenpartition"
data_mib=32
mkfs.fat -C -F 16 -n VEYRA-DATEN -i 5E7A0C0D "$work/data.img" $((data_mib * 1024)) >/dev/null
cat > "$work/LIESMICH.txt" <<'TXT'
Veyra OS: Datenpartition des Entwicklungsabbilds.
Nach jedem Start schreibt der Selbsttest hierher:
  veyra-messung.txt   Ergebnis des Selbsttests und Messwerte (Bootzeit, Speicher, SSD)
  kernel-log.txt      Kernel-Meldungen (dmesg), zur Fehlersuche bei Hardware
TXT
mcopy -i "$work/data.img" "$work/LIESMICH.txt" ::/LIESMICH.txt

echo ">> GPT-Abbild zusammensetzen"
total_mib=$(( 1 + esp_mib + root_mib + data_mib + 1 ))
rm -f "$img"
truncate -s "${total_mib}M" "$img"
sfdisk -q "$img" <<SFDISK
label: gpt
label-id: 5E7A0C0E-0000-4000-8000-000000000000
start=1MiB, size=${esp_mib}MiB, type=U, name="EFI", uuid=5E7A0C0E-0000-4000-8000-0000000000E1
size=${root_mib}MiB, type=L, name="veyra-root", uuid=5E7A0C0E-0000-4000-8000-0000000000E2
size=${data_mib}MiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name="veyra-daten", uuid=5E7A0C0E-0000-4000-8000-0000000000E3
SFDISK
dd if="$work/esp.img" of="$img" bs=1M seek=1 conv=notrunc status=none
dd if="$work/root.img" of="$img" bs=1M seek=$((1 + esp_mib)) conv=notrunc status=none
dd if="$work/data.img" of="$img" bs=1M seek=$((1 + esp_mib + root_mib)) conv=notrunc status=none
sfdisk -l "$img"
echo "Abbild fertig: $img (Kernel $kver, Variante $variante)"
