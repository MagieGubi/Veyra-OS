#!/usr/bin/env bash
# fetch-extra.sh: laedt die Netz-Quellen der Zusatzpakete (packages/base, packages/test)
# nach ZIEL und prueft jede gegen sha256sums im Rezept. Vorhandene, passende Dateien werden
# nicht neu geladen. Danach: vpkg-build --srcdir ZIEL REZEPT.
#
# Aufruf: fetch-extra.sh ZIEL   (im Wurzelverzeichnis des Repositorys)
set -euo pipefail
die() { echo "fetch-extra: $*" >&2; exit 1; }
[ $# -eq 1 ] || die "Aufruf: fetch-extra.sh ZIEL"
dest=$1
mkdir -p "$dest"
cd "$(dirname "$0")/../.."
for r in packages/base/*/recipe.sh packages/test/*/recipe.sh; do
  # shellcheck source=/dev/null
  while read -r url sum; do
    f=$dest/${url##*/}
    [ -n "$sum" ] || die "$r: keine Pruefsumme fuer $url"
    if [ -f "$f" ] && echo "$sum  $f" | sha256sum -c --quiet - 2>/dev/null; then continue; fi
    curl -fsSL --retry 3 -o "$f.teil" "$url" || die "Download gescheitert: $url"
    echo "$sum  $f.teil" | sha256sum -c --quiet - || { rm -f "$f.teil"; die "SHA-256 passt nicht: $url"; }
    mv "$f.teil" "$f"
    echo "geladen: ${url##*/}"
  done < <(sources=(); sha256sums=(); . "$r"
           for i in "${!sources[@]}"; do
             case ${sources[$i]} in *://*) echo "${sources[$i]} ${sha256sums[$i]:-}" ;; esac
           done)
done
