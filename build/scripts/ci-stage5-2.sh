#!/usr/bin/env bash
# Laeuft im Bootstrap-Container (als root, --privileged): Stufe 5, Teil 2 (kitty mit Mesa
# und Go) in chroot. Grundlage: Basissystem aus Stufe 4b, Teil 4, dazu die Pakete aus
# Stufe 5, Teil 1 (ausgepackt wie in 30-packages.sh). Quellen: stage4/sources-6.list; die
# Go-Module fuer kitty laedt build/tools/fetch-gomod.py (Go prueft sie gegen go.sum).
# Erwartet /in/veyra-stage4b-4.tar.zst und /in/pakete-5/*.vpkg; Ergebnis: /out/packages
set -euo pipefail
repo=/repo

cat "$repo"/{toolchain,temptools,stage4}/sources.lock > /out/stage5-2-sources.lock
"$repo/build/scripts/fetch-signed.sh" "$repo/stage4/sources-6.list" /out/stage5-2-sources.lock /sources

# kitten (Go): Module aus go.sum des gerade geprueften kitty-Archivs
kitty=$(grep -vE '^\s*(#|$)' "$repo/packages/desktop/kitty/recipe.sh" | sed -n 's/^pkgver=//p')
tar -xJOf "/sources/kitty-$kitty.tar.xz" "kitty-$kitty/go.sum" > /tmp/kitty-go.sum
python3 "$repo/build/tools/fetch-gomod.py" /tmp/kitty-go.sum "/sources/gomod-kitty-$kitty"

in=$(ls /in/*.tar.zst)
zstd -q -dc "$in" | tar -xpf - -C /
export VEYRA=/veyra
for p in /in/pakete-5/*.vpkg; do
  zstd -q -dc "$p" | tar -xpf - -C "$VEYRA" --strip-components=1 --keep-directory-symlink files
done
mkdir -p "$VEYRA"/{sources,stage4,packages/core}
cp -r /sources/. "$VEYRA/sources/"
cp -r "$repo/stage4/." "$VEYRA/stage4/"
cp /out/stage5-2-sources.lock "$VEYRA/stage4/sources.lock"
cp "$repo/build/scripts/vpkg-build" "$VEYRA/stage4/vpkg-build"
cp -r "$repo/packages/desktop/." "$VEYRA/packages/core/"
chroot "$VEYRA" /usr/sbin/ldconfig
chroot "$VEYRA" /usr/bin/fc-cache -s >/dev/null 2>&1 || true

"$repo/stage4/enter-chroot.sh" /stage4/chroot/30-packages.sh /stage4/order-6.list 2>&1 \
  | tee /out/build-stage5-2.log

mkdir -p /out/packages
for t in "$VEYRA"/pkgs/*.vpkg.tar; do
  out=/out/packages/${t##*/}
  zstd -q -19 -T1 -o "${out%.tar}" < "$t"
done
(cd /out/packages && sha256sum ./*.vpkg > SHA256SUMS)
ls -l /out /out/packages
