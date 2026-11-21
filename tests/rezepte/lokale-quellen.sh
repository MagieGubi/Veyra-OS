#!/usr/bin/env bash
# Prueft fuer alle Rezepte in packages/base und packages/test: jede lokale Quelle (Datei neben
# dem Rezept, keine URL) passt zu ihrer Pruefsumme in sha256sums. Netz-Quellen prueft
# build/scripts/fetch-extra.sh beim Laden.
set -euo pipefail
cd "$(dirname "$0")/../.."
n=0 fehler=0
for r in packages/base/*/recipe.sh packages/test/*/recipe.sh; do
  d=$(dirname "$r")
  # shellcheck source=/dev/null
  while read -r f sum; do
    n=$((n + 1))
    if [ -z "$sum" ] || [ "$sum" != "$(sha256sum "$d/$f" | cut -d' ' -f1)" ]; then
      echo "FEHLER: $r: sha256sums passt nicht zu $f" >&2; fehler=1
    fi
  done < <(sources=(); sha256sums=(); . "$r"
           for i in "${!sources[@]}"; do
             case ${sources[$i]} in *://*) ;; *) echo "${sources[$i]} ${sha256sums[$i]:-}" ;; esac
           done)
done
[ $fehler = 0 ] || exit 1
echo "ok - $n lokale Quellen in Rezepten passen zu ihren Pruefsummen"
