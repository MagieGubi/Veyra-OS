#!/bin/bash
# shellcheck disable=SC1091,SC2154 # Rezepte werden erst zur Laufzeit geladen
# Stufe 4b (in chroot): baut die Pakete einer Reihenfolge-Liste mit vpkg-build und
# installiert jedes sofort nach /, damit die folgenden Pakete darauf aufbauen.
# Die Pakete landen unkomprimiert in /pkgs; komprimiert wird ausserhalb (zstd -19 -T1).
#
# Aufruf: 30-packages.sh /stage4/order-N.list
set -euo pipefail
order=$1
mkdir -p /pkgs /var/lib/veyra-stage
grep -vE '^\s*(#|$)' "$order" | while read -r name; do
  r=/packages/core/$name
  if [ -e "/var/lib/veyra-stage/$name.done" ]; then echo ">> $name schon gebaut"; continue; fi
  echo
  echo "################ $name ################"
  start=$SECONDS
  /stage4/vpkg-build --srcdir /sources --lock /stage4/sources.lock --outdir /pkgs --no-compress "$r"
  pkg=$( . "$r/recipe.sh"; echo "/pkgs/$pkgname-$pkgver-${pkgrel:-1}-x86_64.vpkg.tar" )
  [ -f "$pkg" ] || { echo "Paketdatei fehlt: $pkg" >&2; exit 1; }
  tar -xpf "$pkg" -C / --strip-components=1 --keep-directory-symlink files
  ldconfig
  ( . "$r/recipe.sh"
    if declare -F post_install >/dev/null; then post_install; fi )
  touch "/var/lib/veyra-stage/$name.done"
  echo ">> $name installiert ($((SECONDS - start)) s)"
done
