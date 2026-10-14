#!/usr/bin/env bash
# Phase 5: startet das Abbild in QEMU mit UEFI-Firmware (OVMF) und wartet auf den Login.
# Erfolg = auf der seriellen Konsole erscheint "veyra login:". Ausgabe: Konsolen-Log.
#
# Mit SELFTEST=1 wird danach zusaetzlich auf "VEYRA-SELBSTTEST: OK" gewartet
# (Paket veyra-selftest im Abbild); "VEYRA-SELBSTTEST: FEHLER" ist ein Fehlschlag.
# Danach wird die VM ueber den ACPI-Ausschalter heruntergefahren (wie der Einschaltknopf
# am Rechner): Erfolg nur, wenn das System sich innerhalb von 90 s sauber ausschaltet
# ("reboot: Power down") und dabei keine Einheit fehlschlaegt.
#
# Aufruf: [SELFTEST=1] [MEDIUM=cdrom] image/boot-test.sh ABBILD.img LOG [SEKUNDEN]
set -euo pipefail
img=$1 log=$2 limit=${3:-600}
selftest=${SELFTEST:-0}
# MEDIUM=cdrom: Abbild als CD einlegen (Live-ISO, SATA-CD-Laufwerk wie in VirtualBox)
if [ "${MEDIUM:-disk}" = cdrom ]; then
  drive=(-drive "file=$img,format=raw,media=cdrom,readonly=on")
else
  drive=(-drive "file=$img,format=raw,if=virtio,snapshot=on")
fi
ovmf=/usr/share/OVMF/OVMF_CODE_4M.fd
[ -f "$ovmf" ] || { echo "OVMF nicht gefunden: $ovmf" >&2; exit 1; }
vars=$(mktemp)
mon=$(mktemp -u)
cp /usr/share/OVMF/OVMF_VARS_4M.fd "$vars"
accel=tcg
[ -w /dev/kvm ] && accel=kvm
echo ">> QEMU ($accel), Firmware $ovmf, Grenze ${limit}s"

start=$(date +%s.%N)
qemu-system-x86_64 -machine q35,accel=$accel -m 2048 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf" \
  -drive if=pflash,format=raw,file="$vars" \
  "${drive[@]}" \
  -nographic -serial file:"$log" -monitor unix:"$mon",server,nowait -no-reboot &
qemu=$!
trap 'kill $qemu 2>/dev/null || true; rm -f "$vars" "$mon"' EXIT

timed_out() { [ "$(echo "$(date +%s.%N) - $start > $limit" | bc)" = 1 ]; }
result=1
kstart=""
while kill -0 $qemu 2>/dev/null; do
  if [ -z "$kstart" ] && grep -q 'Linux version' "$log" 2>/dev/null; then kstart=$(date +%s.%N); fi
  if grep -q 'veyra login:' "$log" 2>/dev/null; then result=0; break; fi
  if timed_out; then break; fi
  sleep 0.2
done
end=$(date +%s.%N)
st=0
if [ $result = 0 ] && [ "$selftest" = 1 ]; then
  st=1
  while kill -0 $qemu 2>/dev/null && ! timed_out; do
    if grep -q 'VEYRA-SELBSTTEST: OK' "$log"; then st=0; break; fi
    if grep -q 'VEYRA-SELBSTTEST: FEHLER' "$log"; then break; fi
    sleep 1
  done
fi
echo "----- serielle Konsole -----"
cat "$log" || true
echo "----------------------------"
if [ $result = 0 ]; then
  printf 'ERFOLG: Login-Aufforderung nach %.1f s (gemessen ab QEMU-Start, %s)\n' "$(echo "$end - $start" | bc)" "$accel"
  if [ -n "$kstart" ]; then
    printf '        davon bis zur ersten Kernel-Ausgabe (Firmware): %.1f s, danach %.1f s\n' \
      "$(echo "$kstart - $start" | bc)" "$(echo "$end - $kstart" | bc)"
  fi
else
  echo "FEHLER: keine Login-Aufforderung innerhalb von ${limit}s" >&2
fi
if [ "$selftest" = 1 ] && [ $result = 0 ]; then
  if [ $st = 0 ]; then echo "ERFOLG: Selbsttest bestanden"; else echo "FEHLER: Selbsttest nicht bestanden" >&2; fi
  echo "----- Messwerte (VM) -----"
  grep -a 'VEYRA-MESSUNG' "$log" | sed 's/.*VEYRA-MESSUNG: //' || true
  result=$st
fi
if [ "$selftest" = 1 ] && [ $result = 0 ]; then
  echo "----- Herunterfahren (ACPI-Ausschalter) -----"
  sleep 3   # der Selbsttest kopiert nach "OK" noch seinen Bericht
  zeilen=$(wc -l < "$log")
  python3 - "$mon" <<'PY2'
import socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
s.sendall(b"system_powerdown\n")
time.sleep(1)
PY2
  t0=$(date +%s.%N)
  aus=1
  for _ in $(seq 1 450); do
    if ! kill -0 $qemu 2>/dev/null; then aus=0; break; fi
    sleep 0.2
  done
  dauer=$(echo "$(date +%s.%N) - $t0" | bc)
  tail -n +"$((zeilen + 1))" "$log" > "$log.aus"
  cat "$log.aus"
  if [ $aus != 0 ]; then
    echo "FEHLER: VM hat sich nach 90 s nicht ausgeschaltet" >&2; result=1
  elif ! grep -aq 'reboot: Power down' "$log.aus"; then
    echo "FEHLER: VM beendet, aber ohne 'reboot: Power down' (kein sauberes Ausschalten)" >&2; result=1
  elif grep -aE 'FAILED|Failed (unmounting|deactivating|stopping)|timed out' "$log.aus"; then
    echo "FEHLER: beim Herunterfahren ist etwas fehlgeschlagen (Zeilen oben)" >&2; result=1
  else
    printf 'ERFOLG: sauber heruntergefahren in %.1f s\n' "$dauer"
  fi
  rm -f "$log.aus"
fi
exit $result
