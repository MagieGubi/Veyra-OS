#!/usr/bin/env bash
# Cache-Schluessel fuer Stufe 4: Hash ueber genau die Dateien, von denen eine Stufe abhaengt.
# Gepinnte Pruefsummen (sources.lock) zaehlen nicht: sie aendern nur, was ohnehin geprueft wird.
#
# Aufruf: stage-key.sh 4a | stage-key.sh N   (N = Teil von Stufe 4b; schliesst alle Teile <= N ein;
#         5 = Stufe 5, Desktop-Grundlage, Rezepte in packages/desktop; 6 = Stufe 5, Teil 2, kitty)
set -euo pipefail
cd "$(dirname "$0")/../.."
files=(
  toolchain/versions.sh toolchain/sources.list toolchain/build-cross.sh
  temptools/versions.sh temptools/sources.list temptools/build-temp.sh
  build/container/Dockerfile
  build/scripts/fetch-sources.sh build/scripts/ci-toolchain.sh build/scripts/ci-temptools.sh
  build/scripts/ci-stage4a.sh
  stage4/enter-chroot.sh stage4/versions.sh stage4/sources-chroot.list
  stage4/chroot/10-prepare.sh stage4/chroot/20-temptools.sh
)
if [ "$1" != 4a ]; then
  files+=(build/scripts/vpkg-build build/scripts/ci-stage4b.sh build/scripts/gen-sources-list.sh
          stage4/chroot/30-packages.sh stage4/lfs-12.4-md5sums)
  for ((i = 1; i <= $1; i++)); do
    files+=("stage4/order-$i.list")
    d=packages/core; [ "$i" -lt 5 ] || d=packages/desktop
    while read -r name; do
      while IFS= read -r f; do files+=("$f"); done < <(find "$d/$name" -type f | LC_ALL=C sort)
    done < <(grep -vE '^\s*(#|$)' "stage4/order-$i.list")
  done
fi
if [ "$1" != 4a ] && [ "$1" -ge 4 ]; then
  files+=(build/scripts/ci-stage4b-4.sh build/scripts/fetch-signed.sh stage4/sources-4.list)
fi
if [ "$1" != 4a ] && [ "$1" -ge 5 ]; then
  files+=(build/scripts/ci-stage5.sh stage4/sources-5.list)
fi
if [ "$1" != 4a ] && [ "$1" -ge 6 ]; then
  files+=(build/scripts/ci-stage5-2.sh stage4/sources-6.list build/tools/fetch-gomod.py)
fi
for f in "${files[@]}"; do printf '%s  %s\n' "$(sha256sum < "$f" | cut -d' ' -f1)" "$f"; done \
  | sha256sum | cut -c1-32
