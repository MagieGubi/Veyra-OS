#!/usr/bin/env bash
# Fuehrt ein Skript in der chroot-Umgebung des Zielsystems aus (LFS 12.4, Kapitel 7.3/7.4).
# Haengt /dev, /proc, /sys und /run ein und beim Beenden wieder aus.
#
# Aufruf (als root):
#   VEYRA=/veyra stage4/enter-chroot.sh /pfad/im/zielsystem/skript.sh [ARGUMENTE]
set -euo pipefail
: "${VEYRA:?VEYRA (Wurzel des Zielsystems) setzen}"
[ "$(id -u)" = 0 ] || { echo "enter-chroot.sh braucht root" >&2; exit 1; }
[ $# -ge 1 ] || { echo "Aufruf: enter-chroot.sh SKRIPT [ARGUMENTE]" >&2; exit 1; }

mkdir -p "$VEYRA"/{dev,proc,sys,run}
cleanup() {
  for m in dev/shm dev/pts dev proc sys run; do
    if mountpoint -q "$VEYRA/$m"; then umount -l "$VEYRA/$m" || true; fi
  done
}
trap cleanup EXIT
mountpoint -q "$VEYRA/dev" || mount --bind /dev "$VEYRA/dev"
mountpoint -q "$VEYRA/dev/pts" || mount -t devpts devpts -o gid=5,mode=0620 "$VEYRA/dev/pts"
mountpoint -q "$VEYRA/proc" || mount -t proc proc "$VEYRA/proc"
mountpoint -q "$VEYRA/sys" || mount -t sysfs sysfs "$VEYRA/sys"
mountpoint -q "$VEYRA/run" || mount -t tmpfs tmpfs "$VEYRA/run"
if [ -h "$VEYRA/dev/shm" ]; then
  install -d -m 1777 "$VEYRA$(realpath /dev/shm)"
else
  mountpoint -q "$VEYRA/dev/shm" || mount -t tmpfs -o nosuid,nodev tmpfs "$VEYRA/dev/shm"
fi

chroot "$VEYRA" /usr/bin/env -i \
  HOME=/root TERM="${TERM:-dumb}" PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j${JOBS:-$(nproc)}" SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1767225600}" \
  /bin/bash --login -e "$@"
