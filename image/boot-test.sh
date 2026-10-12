#!/usr/bin/env bash
# Phase 5: startet das Abbild in QEMU mit UEFI-Firmware (OVMF) und wartet auf den Login.
# Erfolg = auf der seriellen Konsole erscheint "veyra login:". Ausgabe: Konsolen-Log.
#
# Aufruf: image/boot-test.sh ABBILD.img LOG [SEKUNDEN]
set -euo pipefail
img=$1 log=$2 limit=${3:-600}
ovmf=/usr/share/OVMF/OVMF_CODE_4M.fd
[ -f "$ovmf" ] || { echo "OVMF nicht gefunden: $ovmf" >&2; exit 1; }
vars=$(mktemp)
cp /usr/share/OVMF/OVMF_VARS_4M.fd "$vars"
accel=tcg
[ -w /dev/kvm ] && accel=kvm
echo ">> QEMU ($accel), Firmware $ovmf, Grenze ${limit}s"

start=$(date +%s.%N)
qemu-system-x86_64 -machine q35,accel=$accel -m 2048 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf" \
  -drive if=pflash,format=raw,file="$vars" \
  -drive file="$img",format=raw,if=virtio,snapshot=on \
  -nographic -serial file:"$log" -monitor none -no-reboot &
qemu=$!
trap 'kill $qemu 2>/dev/null || true; rm -f "$vars"' EXIT

result=1
while kill -0 $qemu 2>/dev/null; do
  if grep -q 'veyra login:' "$log" 2>/dev/null; then result=0; break; fi
  if [ "$(echo "$(date +%s.%N) - $start > $limit" | bc)" = 1 ]; then break; fi
  sleep 1
done
end=$(date +%s.%N)
echo "----- serielle Konsole -----"
cat "$log" || true
echo "----------------------------"
if [ $result = 0 ]; then
  printf 'ERFOLG: Login-Aufforderung nach %.1f s (gemessen ab QEMU-Start, %s)\n' "$(echo "$end - $start" | bc)" "$accel"
else
  echo "FEHLER: keine Login-Aufforderung innerhalb von ${limit}s" >&2
fi
exit $result
