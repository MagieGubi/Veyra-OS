#!/usr/bin/env bash
# Cache-Schluessel fuer Stufe 4: Hash ueber genau die Dateien, von denen eine Stufe abhaengt.
# Gepinnte Pruefsummen (sources.lock) zaehlen nicht: sie aendern nur, was ohnehin geprueft wird.
#
# Aufruf: stage-key.sh 4a | stage-key.sh N   (N = Teil von Stufe 4b; schliesst alle Teile <= N ein)
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
    while read -r name; do
      while IFS= read -r f; do files+=("$f"); done < <(find "packages/core/$name" -type f | LC_ALL=C sort)
    done < <(grep -vE '^\s*(#|$)' "stage4/order-$i.list")
  done
fi
for f in "${files[@]}"; do printf '%s  %s\n' "$(sha256sum < "$f" | cut -d' ' -f1)" "$f"; done \
  | sha256sum | cut -c1-32
