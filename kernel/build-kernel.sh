#!/usr/bin/env bash
# Phase 4: baut den Veyra-Kernel mit der Cross-Toolchain aus Stufe 2.
#
# Schritte: Quelle entpacken, Patches aus patches/series anwenden, x86_64_defconfig plus die
# Fragmente config/veyra-*.config (alphabetisch), bauen, Module in einen Staging-Ordner legen.
# Reproduzierbar: fester Zeitstempel, Nutzer, Host und Build-Pfad; keine Modulsignierung.
#
# Aufruf (als normaler Nutzer, nicht root):
#   VEYRA=/veyra SRC=/sources OUT=/out/kernel kernel/build-kernel.sh
# Ergebnis in $OUT: vmlinuz-VERSION, config-VERSION, System.map-VERSION,
#   modules-VERSION.tar.zst und SHA256SUMS
set -euo pipefail
umask 022

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=VERSION source-path=SCRIPTDIR
. "$here/VERSION"

: "${VEYRA:?VEYRA (Wurzel mit tools/ aus Stufe 2) setzen}"
: "${SRC:?SRC (Verzeichnis mit den Quellen) setzen}"
: "${OUT:?OUT (Ausgabeverzeichnis) setzen}"
[ "$(id -u)" != 0 ] || { echo "Bitte nicht als root ausfuehren" >&2; exit 1; }
VEYRA_TGT=x86_64-veyra-linux-gnu
[ -x "$VEYRA/tools/bin/$VEYRA_TGT-gcc" ] || { echo "Cross-Toolchain (Stufe 2) fehlt in $VEYRA/tools" >&2; exit 1; }

kver=$LINUX_VERSION-veyra$VEYRA_REVISION
export LC_ALL=C TZ=UTC
export PATH=$VEYRA/tools/bin:/usr/bin:/bin
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1767225600}   # 2026-01-01 00:00 UTC
export KBUILD_BUILD_TIMESTAMP="@$SOURCE_DATE_EPOCH"
export KBUILD_BUILD_USER=veyra KBUILD_BUILD_HOST=veyra-build KBUILD_BUILD_VERSION=1
kmake() { make ARCH=x86_64 CROSS_COMPILE="$VEYRA_TGT-" -j"${JOBS:-$(nproc)}" "$@"; }
step() { echo; echo "=== $* ==="; }

# Fester Build-Pfad, damit eingebettete Pfade bei jedem Build gleich sind.
build=${BUILD_DIR:-/work/kbuild}
rm -rf "$build" && mkdir -p "$build" "$OUT"

step "Linux $LINUX_VERSION entpacken"
tar -xf "$SRC/linux-$LINUX_VERSION.tar.xz" -C "$build"
cd "$build/linux-$LINUX_VERSION"

step "Veyra-Patches anwenden"
n=0
while read -r p; do
  case $p in ''|'#'*) continue ;; esac
  echo "   $p"
  patch -p1 --no-backup-if-mismatch < "$here/patches/$p"
  n=$((n + 1))
done < "$here/patches/series"
echo "   $n Patch(es)"

step "Konfiguration: x86_64_defconfig + Veyra-Fragmente"
kmake x86_64_defconfig
printf 'CONFIG_LOCALVERSION="-veyra%s"\n' "$VEYRA_REVISION" > "$build/veyra-99-version.config"
frags=("$here"/config/veyra-*.config "$build/veyra-99-version.config")
scripts/kconfig/merge_config.sh -m .config "${frags[@]}"
kmake olddefconfig

# Jede Option aus den Fragmenten muss in der endgueltigen .config so stehen wie verlangt,
# sonst hat Kconfig sie wegen fehlender Abhaengigkeiten verworfen.
bad=0
while IFS= read -r line; do
  case $line in CONFIG_*=*) ;; *) continue ;; esac
  opt=${line%%=*} val=${line#*=}
  if [ "$val" = n ]; then
    grep -qx "# $opt is not set" .config || ! grep -q "^$opt=" .config || { echo "FEHLER: $opt sollte aus sein" >&2; bad=1; }
  else
    grep -qxF "$line" .config || { echo "FEHLER: $line fehlt (ist: $(grep "^$opt=" .config || echo 'nicht gesetzt'))" >&2; bad=1; }
  fi
done < <(cat "${frags[@]}")
[ $bad = 0 ] || exit 1
echo "   alle Veyra-Optionen gesetzt"

step "Kernel $kver bauen"
kmake bzImage modules
[ "$(kmake -s kernelrelease)" = "$kver" ] || { echo "FEHLER: kernelrelease ist $(kmake -s kernelrelease), erwartet $kver" >&2; exit 1; }

step "Ergebnis nach $OUT"
staging=$build/staging
kmake INSTALL_MOD_PATH="$staging" INSTALL_MOD_STRIP=1 modules_install
rm -f "$staging/lib/modules/$kver/build" "$staging/lib/modules/$kver/source"
install -m644 arch/x86/boot/bzImage "$OUT/vmlinuz-$kver"
install -m644 .config "$OUT/config-$kver"
install -m644 System.map "$OUT/System.map-$kver"
tar --sort=name --format=posix --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
    --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner \
    -C "$staging" -cf - lib | zstd -q -19 -T1 -o "$OUT/modules-$kver.tar.zst"

# Einzelpruefsummen der Module, damit ein Unterschied zwischen zwei Builds genau zuzuordnen ist.
(cd "$staging" && find lib -type f -name '*.ko*' | LC_ALL=C sort | xargs -r sha256sum) > "$OUT/modules.sha256"
(cd "$OUT" && sha256sum "vmlinuz-$kver" "config-$kver" "System.map-$kver" "modules-$kver.tar.zst" modules.sha256 > SHA256SUMS)
cat "$OUT/SHA256SUMS"
echo "   Module: $(wc -l < "$OUT/modules.sha256")"
echo
echo "Veyra-Kernel $kver fertig."
