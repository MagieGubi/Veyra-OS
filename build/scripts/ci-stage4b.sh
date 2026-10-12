#!/usr/bin/env bash
# Laeuft im Bootstrap-Container (als root, --privileged): Stufe 4b, Teil N, in chroot.
# Erwartet das Ergebnis der vorigen Stufe als /in/*.tar.zst.
# Ergebnis: /out/packages/*.vpkg, /out/veyra-stage4b-N.tar.zst
#
# Aufruf: ci-stage4b.sh N
set -euo pipefail
repo=/repo
part=$1
order=$repo/stage4/order-$part.list

# Alle bisher gepinnten Quellen in eine Sperrdatei; neue werden nach Pruefung ergaenzt.
cat "$repo"/{toolchain,temptools,stage4}/sources.lock > /out/stage4-sources.lock
"$repo/build/scripts/gen-sources-list.sh" "$order" "$repo/packages/core" "$repo/stage4/lfs-12.4-md5sums" \
  > "/out/sources-4b-$part.list"
"$repo/build/scripts/fetch-sources.sh" --lock "/out/sources-4b-$part.list" /out/stage4-sources.lock /sources

in=$(ls /in/*.tar.zst)
zstd -q -dc "$in" | tar -xpf - -C /
export VEYRA=/veyra
mkdir -p "$VEYRA"/{sources,stage4,packages}
cp /sources/* "$VEYRA/sources/"
cp -r "$repo/stage4/." "$VEYRA/stage4/"
cp /out/stage4-sources.lock "$VEYRA/stage4/sources.lock"
cp "$repo/build/scripts/vpkg-build" "$VEYRA/stage4/vpkg-build"
cp -r "$repo/packages/core" "$VEYRA/packages/core"

"$repo/stage4/enter-chroot.sh" /stage4/chroot/30-packages.sh "/stage4/order-$part.list" 2>&1 \
  | tee "/out/build-stage4b-$part.log"

mkdir -p /out/packages
for t in "$VEYRA"/pkgs/*.vpkg.tar; do
  out=/out/packages/${t##*/}
  zstd -q -19 -T1 -o "${out%.tar}" < "$t"
done
(cd /out/packages && sha256sum ./*.vpkg > SHA256SUMS)

rm -rf "$VEYRA"/{sources,stage4,packages,pkgs}
tar --sort=name --numeric-owner -C / -cf - veyra | zstd -q -T0 -19 -o "/out/veyra-stage4b-$part.tar.zst"
ls -l /out /out/packages
