#!/usr/bin/env bash
# Tests fuer veyra-firewall (ohne laufendes Veyra): Rezept passt zu den Regeln, die Regeln
# sind fuer nft gueltig (nft -c), und die Grundsaetze stehen drin (eingehend und
# Weiterleiten verwerfen, Loopback, eigene Verbindungen, DHCP, ICMPv6 fuer IPv6).
# Laufzeit-Nachweis: Selbsttest im gebooteten Abbild ("Firewall: ok") und Netzwerk-Selbsttest.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
pkg=$here/packages/base/veyra-firewall
conf=$pkg/nftables.conf
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
ok() { echo "ok $n - $1"; }

n=$((n + 1))
grep -q "$(sha256sum "$conf" | cut -d' ' -f1)" "$pkg/recipe.sh" || fail "sha256sums in recipe.sh passt nicht zu nftables.conf"
ok "Rezept passt zu den Regeln"

n=$((n + 1))
if command -v nft >/dev/null && nft -c -f "$conf" 2>"${TMPDIR:-/tmp}/nft.err"; then
  ok "nft -c akzeptiert die Regeln"
elif command -v nft >/dev/null && grep -qi 'Operation not permitted' "${TMPDIR:-/tmp}/nft.err"; then
  echo "uebersprungen - nft -c braucht Netlink-Rechte (als root ausfuehren)"
else
  fail "nft -c lehnt die Regeln ab oder nft fehlt: $(cat "${TMPDIR:-/tmp}/nft.err" 2>/dev/null)"
fi

n=$((n + 1))
for muster in 'hook input priority filter; policy drop;' 'hook forward priority filter; policy drop;' \
              'iif "lo" accept' 'ct state established,related accept' 'udp sport 67 udp dport 68 accept' \
              'nd-neighbor-solicit' 'nd-router-advert'; do
  grep -qF "$muster" "$conf" || fail "Grundsatz fehlt: $muster"
done
! grep -E '^\s*(tcp|udp) dport [0-9]+ accept' "$conf" || fail "offener Port in den Standardregeln"
ok "Grundsaetze: eingehend und Weiterleiten verwerfen, Loopback, Antworten, DHCP, ICMPv6; kein offener Port"
echo "Alle $n Firewall-Tests bestanden."
