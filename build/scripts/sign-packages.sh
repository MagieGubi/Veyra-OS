#!/usr/bin/env bash
# Signiert .vpkg-Dateien mit dem Veyra-Paketschluessel (Ed25519) und legt je Paket
# PAKET.vpkg.sig daneben. Vorher wird geprueft, dass der private Schluessel zum
# oeffentlichen Schluessel im Repository passt (packages/base/veyra-keyring/veyra-2026.pem).
#
# Aufruf: sign-packages.sh PRIVATER-SCHLUESSEL.pem VERZEICHNIS...
#   Alle .vpkg-Dateien in den Verzeichnissen (auch in Unterordnern) werden signiert.
set -euo pipefail
die() { echo "sign-packages: $*" >&2; exit 1; }
[ $# -ge 2 ] || die "Aufruf: sign-packages.sh SCHLUESSEL.pem VERZEICHNIS..."
key=$1; shift
pub=$(cd "$(dirname "$0")/../.." && pwd)/packages/base/veyra-keyring/veyra-2026.pem
[ -f "$key" ] || die "Schluessel fehlt: $key"
[ "$(openssl pkey -in "$key" -pubout)" = "$(cat "$pub")" ] \
  || die "privater Schluessel passt nicht zum Veyra-Schluessel"
n=0
while IFS= read -r -d '' p; do
  openssl pkeyutl -sign -inkey "$key" -rawin -in "$p" -out "$p.sig"
  openssl pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$p" -sigfile "$p.sig" >/dev/null \
    || die "Signatur nicht pruefbar: $p"
  n=$((n + 1))
done < <(find "$@" -name '*.vpkg' -print0 | LC_ALL=C sort -z)
echo "sign-packages: $n Paket(e) signiert"
