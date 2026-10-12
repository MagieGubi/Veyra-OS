#!/usr/bin/env bash
# Laeuft im Bootstrap-Container (als root): Stufe 3 auf Basis der Stufe-2-Toolchain.
# Erwartet /in/veyra-toolchain-stage2.tar.zst; Ergebnis: /out/veyra-temptools-stage3.tar.zst
set -euo pipefail
repo=/repo
for part in toolchain temptools; do
  cp "$repo/$part/sources.lock" "/out/$part-sources.lock"
  "$repo/build/scripts/fetch-sources.sh" --lock "$repo/$part/sources.list" "/out/$part-sources.lock" /sources
done
echo "--- temptools/sources.lock nach dem Abruf ---"
cat /out/temptools-sources.lock

zstd -q -dc /in/veyra-toolchain-stage2.tar.zst | tar -xf - -C /
install -d -o veyra -g veyra /work
cp -r "$repo/toolchain" "$repo/temptools" /work/
chown -R veyra:veyra /veyra /work /sources
su veyra -c "VEYRA=/veyra SRC=/sources TMPDIR=/work JOBS=$(nproc) bash /work/temptools/build-temp.sh" 2>&1 \
  | tee /out/build-temp.log

# /tools wird ab Stufe 4 nicht mehr gebraucht; Ergebnis gehoert ab jetzt root (wie in LFS 7.2).
chown -R root:root /veyra
tar --sort=name --numeric-owner -C / -cf - veyra | zstd -q -T0 -19 -o /out/veyra-temptools-stage3.tar.zst
ls -l /out
