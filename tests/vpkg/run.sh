#!/usr/bin/env bash
# Tests fuer vpkg-build und vpkg-verify:
#  1. Paket bauen, zweimal: beide Pakete muessen bit-identisch sein.
#  2. Signieren und pruefen: muss gelingen.
#  3. Manipuliertes Paket (geaenderte Datei, gleiche Signatur): muss abgelehnt werden.
#  4. Falscher Schluessel: muss abgelehnt werden.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
bin=$here/build/scripts
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail() { echo "FEHLER: $*" >&2; exit 1; }

openssl genpkey -algorithm ed25519 -out "$t/key.pem" 2>/dev/null
openssl pkey -in "$t/key.pem" -pubout -out "$t/pub.pem"
openssl genpkey -algorithm ed25519 -out "$t/other.pem" 2>/dev/null
openssl pkey -in "$t/other.pem" -pubout -out "$t/other-pub.pem"

r=$here/packages/base/veyra-release
"$bin/vpkg-build" --srcdir "$t" --outdir "$t/a" --sign-key "$t/key.pem" "$r" >/dev/null
"$bin/vpkg-build" --srcdir "$t" --outdir "$t/b" "$r" >/dev/null
a=$(sha256sum "$t"/a/*.vpkg | cut -d' ' -f1)
b=$(sha256sum "$t"/b/*.vpkg | cut -d' ' -f1)
[ "$a" = "$b" ] || fail "zwei Builds sind nicht identisch"
echo "ok 1 - reproduzierbar ($a)"

pkg=$(ls "$t"/a/*.vpkg)
"$bin/vpkg-verify" --pubkey "$t/pub.pem" "$pkg" >/dev/null || fail "gueltiges Paket abgelehnt"
echo "ok 2 - Signatur und Manifest gueltig"

# Manipulation: Datei im Paket aendern, neu packen, alte Signatur behalten.
mkdir "$t/x"
zstd -q -dc "$pkg" | tar -xf - -C "$t/x"
echo "Boese OS" > "$t/x/files/etc/veyra-release"
tar -C "$t/x" -cf - manifest.toml files | zstd -q -o "$t/evil.vpkg"
cp "$pkg.sig" "$t/evil.vpkg.sig"
if "$bin/vpkg-verify" --pubkey "$t/pub.pem" "$t/evil.vpkg" 2>/dev/null; then fail "manipuliertes Paket angenommen (Signatur)"; fi
if "$bin/vpkg-verify" "$t/evil.vpkg" 2>/dev/null; then fail "manipuliertes Paket angenommen (Manifest)"; fi
echo "ok 3 - manipuliertes Paket abgelehnt"

if "$bin/vpkg-verify" --pubkey "$t/other-pub.pem" "$pkg" 2>/dev/null; then fail "falscher Schluessel angenommen"; fi
echo "ok 4 - falscher Schluessel abgelehnt"
