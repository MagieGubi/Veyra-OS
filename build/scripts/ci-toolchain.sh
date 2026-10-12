#!/usr/bin/env bash
# Laeuft im Bootstrap-Container (als root): Quellen holen, dann Stufe 2 als Nutzer "veyra" bauen.
# Ergebnis: /out/veyra-toolchain-stage2.tar.zst und /out/sources.lock
set -euo pipefail
repo=/repo
cp "$repo/toolchain/sources.lock" /out/sources.lock
"$repo/build/scripts/fetch-sources.sh" --lock "$repo/toolchain/sources.list" /out/sources.lock /sources
echo "--- sources.lock nach dem Abruf ---"
cat /out/sources.lock

install -d -o veyra -g veyra /veyra /work
su veyra -c "VEYRA=/veyra SRC=/sources TMPDIR=/work JOBS=$(nproc) $repo/toolchain/build-cross.sh" 2>&1 \
  | tee /out/build-cross.log

tar --sort=name --numeric-owner --owner=0 --group=0 -C / -cf - veyra | zstd -q -T0 -19 -o /out/veyra-toolchain-stage2.tar.zst
ls -l /out
