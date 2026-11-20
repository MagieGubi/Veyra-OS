#!/usr/bin/env bash
# Laeuft im Bootstrap-Container (als root, --privileged): Stufe 5, Desktop-Grundlage, in
# chroot auf dem Basissystem aus Stufe 4b, Teil 4. Quellen prueft fetch-signed.sh
# (stage4/sources-5.list). Das Ergebnis sind nur Pakete: das Basissystem bleibt unveraendert.
# Erwartet /in/veyra-stage4b-4.tar.zst; Ergebnis: /out/packages/*.vpkg, /out/build-stage5.log
set -euo pipefail
repo=/repo

cat "$repo"/{toolchain,temptools,stage4}/sources.lock > /out/stage5-sources.lock
"$repo/build/scripts/fetch-signed.sh" "$repo/stage4/sources-5.list" /out/stage5-sources.lock /sources

in=$(ls /in/*.tar.zst)
zstd -q -dc "$in" | tar -xpf - -C /
export VEYRA=/veyra
mkdir -p "$VEYRA"/{sources,stage4,packages/core}
cp /sources/* "$VEYRA/sources/"
cp -r "$repo/stage4/." "$VEYRA/stage4/"
cp /out/stage5-sources.lock "$VEYRA/stage4/sources.lock"
cp "$repo/build/scripts/vpkg-build" "$VEYRA/stage4/vpkg-build"
# 30-packages.sh sucht Rezepte unter /packages/core
cp -r "$repo/packages/desktop/." "$VEYRA/packages/core/"

"$repo/stage4/enter-chroot.sh" /stage4/chroot/30-packages.sh /stage4/order-5.list 2>&1 \
  | tee /out/build-stage5.log

mkdir -p /out/packages
for t in "$VEYRA"/pkgs/*.vpkg.tar; do
  out=/out/packages/${t##*/}
  zstd -q -19 -T1 -o "${out%.tar}" < "$t"
done
(cd /out/packages && sha256sum ./*.vpkg > SHA256SUMS)
ls -l /out /out/packages
