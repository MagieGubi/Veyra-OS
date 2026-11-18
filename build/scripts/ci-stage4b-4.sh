#!/usr/bin/env bash
# Laeuft im Bootstrap-Container (als root, --privileged): Stufe 4b, Teil 4, in chroot.
# Wie ci-stage4b.sh, aber fuer Pakete ausserhalb von LFS 12.4: deren Quellen prueft
# fetch-signed.sh (Signatur des Projekts, Schluessel aus zwei Quellen) statt LFS-MD5.
# Eigene Datei, damit sich die Cache-Schluessel der Teile 1 bis 3 nicht aendern.
# Erwartet /in/veyra-stage4b-3.tar.zst; Ergebnis: /out/packages/*.vpkg, /out/veyra-stage4b-4.tar.zst
set -euo pipefail
repo=/repo

cat "$repo"/{toolchain,temptools,stage4}/sources.lock > /out/stage4-sources.lock
"$repo/build/scripts/fetch-signed.sh" "$repo/stage4/sources-4.list" /out/stage4-sources.lock /sources

in=$(ls /in/*.tar.zst)
zstd -q -dc "$in" | tar -xpf - -C /
export VEYRA=/veyra
mkdir -p "$VEYRA"/{sources,stage4,packages}
cp /sources/* "$VEYRA/sources/"
cp -r "$repo/stage4/." "$VEYRA/stage4/"
cp /out/stage4-sources.lock "$VEYRA/stage4/sources.lock"
cp "$repo/build/scripts/vpkg-build" "$VEYRA/stage4/vpkg-build"
cp -r "$repo/packages/core" "$VEYRA/packages/core"

"$repo/stage4/enter-chroot.sh" /stage4/chroot/30-packages.sh /stage4/order-4.list 2>&1 \
  | tee /out/build-stage4b-4.log

mkdir -p /out/packages
for t in "$VEYRA"/pkgs/*.vpkg.tar; do
  out=/out/packages/${t##*/}
  zstd -q -19 -T1 -o "${out%.tar}" < "$t"
done
(cd /out/packages && sha256sum ./*.vpkg > SHA256SUMS)

rm -rf "$VEYRA"/{sources,stage4,packages,pkgs}
tar --sort=name --numeric-owner -C / -cf - veyra | zstd -q -T0 -19 -o /out/veyra-stage4b-4.tar.zst
ls -l /out /out/packages
