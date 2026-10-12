#!/usr/bin/env bash
# Laeuft im Bootstrap-Container (als root, --privileged): Stufe 4a in chroot.
# Erwartet /in/veyra-temptools-stage3.tar.zst; Ergebnis: /out/veyra-stage4a.tar.zst
set -euo pipefail
repo=/repo
cp "$repo/stage4/sources.lock" /out/stage4-sources.lock
"$repo/build/scripts/fetch-sources.sh" --lock "$repo/stage4/sources-chroot.list" /out/stage4-sources.lock /sources

zstd -q -dc /in/veyra-temptools-stage3.tar.zst | tar -xf - -C /
export VEYRA=/veyra
mkdir -p "$VEYRA/sources" "$VEYRA/stage4"
cp /sources/* "$VEYRA/sources/"
cp -r "$repo/stage4/." "$VEYRA/stage4/"
{
  "$repo/stage4/enter-chroot.sh" /stage4/chroot/10-prepare.sh
  "$repo/stage4/enter-chroot.sh" /stage4/chroot/20-temptools.sh
} 2>&1 | tee /out/build-stage4a.log

rm -rf "$VEYRA/sources" "$VEYRA/stage4"
tar --sort=name --numeric-owner -C / -cf - veyra | zstd -q -T0 -19 -o /out/veyra-stage4a.tar.zst
ls -l /out
