#!/usr/bin/env bash
# Prueft, ob jede Quelle der Basispakete (stage4/order-*.list) in einer sources.lock steht.
# Neue Quellen sind erlaubt (das CI prueft sie per Signatur bzw. LFS-MD5 und zeigt den
# SHA-256 an), werden aber als Warnung gemeldet, bis sie im Repository festgeschrieben sind.
#
# Aufruf: check-pinned.sh   (im Wurzelverzeichnis des Repositorys)
set -euo pipefail
cd "$(dirname "$0")/../.."
locks=(toolchain/sources.lock temptools/sources.lock stage4/sources.lock)
open=0
while read -r name; do
  # shellcheck source=/dev/null
  while read -r f; do
    if ! awk -v f="$f" '$2 == f {found=1} END {exit !found}' "${locks[@]}"; then
      echo "::warning::Quelle nicht festgeschrieben: $f ($name)"
      open=$((open + 1))
    fi
  done < <(sources=(); . "packages/core/$name/recipe.sh"; for u in "${sources[@]}"; do echo "${u##*/}"; done)
done < <(grep -vhE '^\s*(#|$)' stage4/order-*.list)
echo "Nicht festgeschriebene Quellen: $open"
