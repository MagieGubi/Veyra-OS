#!/usr/bin/env bash
# Tests fuer veyra-bluetooth (packages/base/veyra-bluetooth) ohne Funk: bluetoothctl und
# systemctl sind Attrappen mit festen Antworten, die ihre Aufrufe protokollieren.
# Muster "Befehl && Pruefung || fail" ist hier gewollt (fail beendet den Test).
# shellcheck disable=SC2015
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
d=$here/packages/base/veyra-bluetooth
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail() { echo "FEHLER: $*" >&2; exit 1; }
n=0
ok() { n=$((n + 1)); echo "ok $n - $*"; }

# shellcheck source=packages/base/veyra-bluetooth/recipe.sh
( sources=(); sha256sums=(); . "$d/recipe.sh"
  for i in "${!sources[@]}"; do
    [ "${sha256sums[$i]}" = "$(sha256sum "$d/${sources[$i]}" | cut -d' ' -f1)" ] \
      || fail "sha256sums in $d/recipe.sh passt nicht zu ${sources[$i]}"
  done ) || exit 1
ok "Rezept-Pruefsummen aktuell"

mkdir -p "$t/bin" "$t/sys/class/rfkill/rfkill0"
echo bluetooth > "$t/sys/class/rfkill/rfkill0/type"
echo 0 > "$t/sys/class/rfkill/rfkill0/soft"
echo 0 > "$t/sys/class/rfkill/rfkill0/hard"
: > "$t/gekoppelt"
cat > "$t/bin/bluetoothctl" <<'BT'
#!/bin/sh
echo "bluetoothctl $*" >> "$T/aufrufe"
while [ "${1#--}" != "$1" ]; do shift 2; done
case "$1" in
  list) printf '\033[0;94mController\033[0m 00:AA:01:00:00:23 veyra [default]\n' ;;
  show) printf 'Controller 00:AA:01:00:00:23 (public)\n\tName: veyra\n\tPowered: yes\n\tDiscoverable: no\n' ;;
  devices) echo "Device 11:22:33:44:55:66 Kopfhoerer"; echo "Device 77:88:99:AA:BB:CC Maus" ;;
  info)
    case "$2" in
      11:22:33:44:55:66) p=no; grep -q 11:22 "$T/gekoppelt" && p=yes
        printf 'Device %s (public)\n\tName: Kopfhoerer\n\tIcon: audio-headset\n\tPaired: %s\n\tTrusted: %s\n\tConnected: %s\n' "$2" $p $p $p ;;
      77:88:99:AA:BB:CC) printf 'Device %s (public)\n\tName: Maus\n\tIcon: input-mouse\n\tPaired: yes\n\tTrusted: yes\n\tConnected: no\n' "$2" ;;
      *) echo "Device $2 not available"; exit 1 ;;
    esac ;;
  pair) [ "$2" = 11:22:33:44:55:66 ] && echo "$2" >> "$T/gekoppelt" && echo "Pairing successful" || { echo "Failed to pair"; exit 1; } ;;
  connect) echo "Connection successful" ;;
  disconnect) echo "Successful disconnected" ;;
  remove) echo "Device has been removed" ;;
  *) echo "ok" ;;
esac
BT
printf '#!/bin/sh\necho active\n' > "$t/bin/systemctl"
printf '#!/bin/sh\necho "Kernel: Bluetooth: hci0: 00:AA:01:00:00:23 bereit"\n' > "$t/bin/journalctl"
chmod +x "$t/bin/"*
vb() { T=$t PATH="$t/bin:$PATH" VEYRA_BLUETOOTH_SYS="$t/sys" python3 "$d/veyra-bluetooth" "$@"; }

out=$(vb status)
grep -q '^Controller veyra (Standard): an$' <<<"$out" && grep -q '^Geraete: 1 gekoppelt, 0 verbunden' <<<"$out" \
  && ! grep -q Funksperre <<<"$out" || fail "status: $out"
ok "status: Dienst, Controller, Geraetezahl"

echo 1 > "$t/sys/class/rfkill/rfkill0/soft"
out=$(vb status)
grep -q '^Funksperre: rfkill0 (per Software)' <<<"$out" || fail "Funksperre nicht gemeldet: $out"
echo 0 > "$t/sys/class/rfkill/rfkill0/soft"
ok "status meldet Funksperre"

vb geraete --json > "$t/g.json"
python3 - "$t/g.json" <<'PY' || fail "geraete --json: $(cat "$t/g.json")"
import json, sys
g = {x["adresse"]: x for x in json.load(open(sys.argv[1]))}
assert g["11:22:33:44:55:66"]["art"] == "audio-headset" and not g["11:22:33:44:55:66"]["gekoppelt"]
assert g["77:88:99:AA:BB:CC"]["gekoppelt"] and g["77:88:99:AA:BB:CC"]["vertraut"]
PY
ok "geraete --json"

out=$(vb koppeln 11:22:33:44:55:66 --ohne-rueckfrage)
grep -q '^Gekoppelt und vertraut: Kopfhoerer, verbunden$' <<<"$out" || fail "koppeln: $out"
grep -q 'bluetoothctl --agent NoInputNoOutput --timeout 30 pair 11:22:33:44:55:66' "$t/aufrufe" \
  && grep -q 'bluetoothctl trust 11:22:33:44:55:66' "$t/aufrufe" || fail "koppeln-Aufrufe: $(cat "$t/aufrufe")"
ok "koppeln: pair, trust, connect"

out=$(vb koppeln 00:00:00:00:00:01 --ohne-rueckfrage 2>&1) && fail "Fehlschlag mit Status 0"
grep -q 'gescheitert' <<<"$out" || fail "Fehlschlag nicht gemeldet: $out"
out=$(vb koppeln kaputt 2>&1) && fail "falsche Adresse mit Status 0"
grep -q 'keine Bluetooth-Adresse' <<<"$out" || fail "falsche Adresse angenommen: $out"
ok "koppeln: Fehler und falsche Adresse"

out=$(vb trenne 77:88:99:aa:bb:cc; vb entferne 77:88:99:AA:BB:CC)
grep -q '^Getrennt: 77:88:99:AA:BB:CC' <<<"$out" && grep -q '^Entfernt: 77:88:99:AA:BB:CC' <<<"$out" \
  || fail "trenne/entferne: $out"
ok "trenne und entferne"

out=$(vb diagnose)
grep -q '===== Controller' <<<"$out" && ! grep -qiE '([0-9a-f]{2}:){5}[0-9a-f]{2}' <<<"${out//xx:xx:xx:xx:xx:xx/}" \
  || fail "diagnose enthaelt Adressen: $out"
ok "diagnose ohne Geraeteadressen"
echo "Alle $n Tests bestanden."
