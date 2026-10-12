#!/usr/bin/env bash
# Laeuft im Bootstrap-Container (als root): baut den Veyra-Kernel (Phase 4) mit der Stufe-2-Toolchain.
# Erwartet /in/veyra-toolchain-stage2.tar.zst; Ergebnis in /out/kernel, Quellen-Sperre in /out/kernel-sources.lock
set -euo pipefail
repo=/repo

# Zusaetzliche Host-Werkzeuge fuer den Kernel-Build (objtool, Kconfig, Zertifikats-Tools).
# Hier statt im Dockerfile, damit sich der Cache von Stufe 2 und 3 nicht aendert.
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  flex libelf-dev libssl-dev cpio kmod >/dev/null

cp "$repo/kernel/sources.lock" /out/kernel-sources.lock
"$repo/build/scripts/fetch-sources.sh" --lock "$repo/kernel/sources.list" /out/kernel-sources.lock /sources

zstd -q -dc /in/veyra-toolchain-stage2.tar.zst | tar -xf - -C /
install -d -o veyra -g veyra /work /out/kernel
cp -r "$repo/kernel" /work/kernel
chown -R veyra:veyra /work /sources
su veyra -c "VEYRA=/veyra SRC=/sources OUT=/out/kernel BUILD_DIR=/work/kbuild JOBS=$(nproc) bash /work/kernel/build-kernel.sh" 2>&1 \
  | tee /out/build-kernel.log
