#!/usr/bin/env bash
# Erzeugt aus den Rezepten einer Reihenfolge-Liste eine Quellenliste fuer fetch-sources.sh.
# GNU-Archive werden per Signatur (.sig) geprueft, alle anderen per MD5 aus LFS 12.4.
#
# Aufruf: gen-sources-list.sh ORDER.list PAKET-VERZ LFS-MD5SUMS > sources.list
set -euo pipefail
order=$1 pkgs=$2 md5s=$3
grep -vE '^\s*(#|$)' "$order" | while read -r name; do
  r=$pkgs/$name/recipe.sh
  [ -f "$r" ] || { echo "Rezept fehlt: $r" >&2; exit 1; }
  # shellcheck source=/dev/null
  ( sources=(); . "$r"
    for u in "${sources[@]}"; do
      f=${u##*/}
      if [[ $u == https://ftp.gnu.org/gnu/* ]]; then
        echo "$u $u.sig"
      else
        m=$(awk -v f="$f" '$2 == f {print $1}' "$md5s")
        [ -n "$m" ] || { echo "Keine Pruefmoeglichkeit fuer $f" >&2; exit 1; }
        echo "$u md5:$m"
      fi
    done )
done
