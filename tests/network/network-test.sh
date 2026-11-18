#!/usr/bin/env bash
# Tests fuer veyra-network (packages/base/veyra-network) mit nachgebautem /sys und
# Ersatzprogrammen fuer ip, resolvectl, timedatectl, systemctl und iwctl.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
pkg=$here/packages/base/veyra-network
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
ok() { echo "ok $n - $1"; }
export VEYRA_NETWORK_SYS=$t/sys PATH=$t/bin:$PATH
vn() { python3 "$pkg/veyra-network" "$@"; }

n=$((n + 1))
grep -q "$(sha256sum "$pkg/veyra-network" | cut -d' ' -f1)" "$pkg/recipe.sh" \
  || fail "sha256sums in $pkg/recipe.sh passt nicht zu veyra-network"
ok "Rezept passt zum Programm"

mkdir -p "$t/sys/class/net/enp3s0/device" "$t/sys/class/net/wlan0/device" "$t/sys/class/net/wlan0/wireless" \
  "$t/sys/class/net/lo" "$t/sys/class/net/br0" "$t/sys/class/rfkill/rfkill0" "$t/drivers/r8169" "$t/drivers/iwlwifi" "$t/bin"
ln -s "$t/drivers/r8169" "$t/sys/class/net/enp3s0/device/driver"
ln -s "$t/drivers/iwlwifi" "$t/sys/class/net/wlan0/device/driver"
echo up > "$t/sys/class/net/enp3s0/operstate"; echo down > "$t/sys/class/net/wlan0/operstate"
echo phy0 > "$t/sys/class/rfkill/rfkill0/name"; echo wlan > "$t/sys/class/rfkill/rfkill0/type"
echo 1 > "$t/sys/class/rfkill/rfkill0/soft"; echo 0 > "$t/sys/class/rfkill/rfkill0/hard"
cat > "$t/bin/ip" <<'SH'
#!/bin/sh
case "$*" in
  "-j addr show") echo '[{"ifname":"enp3s0","address":"aa:bb:cc:dd:ee:ff","addr_info":[{"local":"192.168.1.20","prefixlen":24,"scope":"global"},{"local":"fe80::1","prefixlen":64,"scope":"link"}]}]' ;;
  "-j -4 route show default") echo '[{"gateway":"192.168.1.1","dev":"enp3s0"}]' ;;
  *) echo '[]' ;;
esac
SH
cat > "$t/bin/resolvectl" <<'SH'
#!/bin/sh
case "$1" in
  dns) printf 'Global:\nLink 2 (enp3s0): 192.168.1.1\n' ;;
  query) [ "$3" = kaputt.invalid ] && { echo "kaputt.invalid: resolve call failed" >&2; exit 1; }
         echo "$3: 93.184.215.14 -- link: enp3s0" ;;
  status) echo "Link 2 (enp3s0) MAC aa:bb:cc:dd:ee:ff psk=geheim123" ;;
esac
SH
cat > "$t/bin/timedatectl" <<'SH'
#!/bin/sh
echo yes
SH
cat > "$t/bin/systemctl" <<'SH'
#!/bin/sh
[ "$1" = is-active ] && { echo "${IWD_ZUSTAND:-active}"; exit 0; }
echo "keine"
SH
cat > "$t/bin/iwctl" <<'SH'
#!/bin/sh
echo "$*" >> "$IWCTL_LOG"
[ "$3" = get-networks ] && printf '  Netz-A   psk   ****\n  Netz-B   open  **\n'
exit 0
SH
chmod +x "$t/bin/"*
export IWCTL_LOG=$t/iwctl.log

n=$((n + 1))
vn status > "$t/out"
grep -q '^enp3s0 *Ethernet *up *192.168.1.20/24$' "$t/out" || fail "status: $(cat "$t/out")"
grep -q '^wlan0 *WLAN *down *-$' "$t/out" || fail "WLAN fehlt: $(cat "$t/out")"
grep -q '^Standardroute: 192.168.1.1 ueber enp3s0$' "$t/out" || fail "Route fehlt"
grep -q '^DNS: *Link 2 (enp3s0): 192.168.1.1$' "$t/out" || fail "DNS fehlt"
grep -q '^Zeitabgleich:  synchron$' "$t/out" || fail "Zeitabgleich fehlt"
grep -q 'Funk gesperrt: phy0' "$t/out" || fail "rfkill-Sperre nicht gemeldet"
grep -q -e 'br0' -e '^lo' "$t/out" && fail "virtuelle Geraete aufgefuehrt"
ok "status: Geraete mit Adressen, Route, DNS, Zeitabgleich, Funksperre"

n=$((n + 1))
vn wlan liste > "$t/out"
grep -q 'Netz-A' "$t/out" || fail "wlan liste ohne Netze"
grep -qx 'station wlan0 scan' "$t/iwctl.log" || fail "kein Scan: $(cat "$t/iwctl.log")"
vn wlan verbinde Netz-A > /dev/null
grep -qx 'station wlan0 connect Netz-A' "$t/iwctl.log" || fail "verbinde ruft iwctl falsch auf"
if IWD_ZUSTAND=inactive vn wlan liste 2> "$t/err"; then fail "iwd aus, trotzdem Erfolg"; fi
grep -q 'iwd laeuft nicht' "$t/err" || fail "falsche Meldung: $(cat "$t/err")"
ok "wlan: Netze ueber iwctl, verbinden ohne Passwort auf der Kommandozeile, iwd aus klar gemeldet"

n=$((n + 1))
vn dns-test > "$t/out" || fail "dns-test: $(cat "$t/out")"
grep -q 'DNS-Test ok: example.org -> 93.184.215.14' "$t/out" || fail "dns-test: $(cat "$t/out")"
if vn dns-test kaputt.invalid > "$t/out"; then fail "nicht aufloesbarer Name als ok gemeldet"; fi
grep -q 'DNS-Test FEHLER' "$t/out" || fail "Fehler nicht gemeldet"
ok "dns-test: Erfolg und Fehler"

n=$((n + 1))
vn diagnose > "$t/out"
for s in '===== Geraete' '===== Funk (rfkill)' '===== resolvectl' '===== Dienste mit Fehlern'; do
  grep -qF "$s" "$t/out" || fail "Abschnitt fehlt: $s"
done
if grep -q -e 'aa:bb:cc' -e 'geheim123' "$t/out"; then fail "MAC-Adresse oder Passwort in der Diagnose"; fi
ok "diagnose: alle Abschnitte, ohne MAC-Adressen und Passwoerter"

echo "Alle $n Netzwerk-Tests bestanden."
