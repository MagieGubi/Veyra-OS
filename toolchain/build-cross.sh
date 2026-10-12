#!/usr/bin/env bash
# Stufe 2: Cross-Toolchain fuer x86_64-veyra-linux-gnu.
#
# Baut nach der Methode von Linux From Scratch (Kapitel 5):
#   binutils (Durchlauf 1), GCC (Durchlauf 1), Linux-API-Header, glibc, libstdc++
# Ergebnis: $VEYRA/tools (Cross-Compiler) und $VEYRA/usr (glibc + Header des Zielsystems).
#
# Aufruf (als normaler Nutzer, nicht root):
#   VEYRA=/veyra SRC=/sources toolchain/build-cross.sh
set -euo pipefail
set +h
umask 022

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=versions.sh source-path=SCRIPTDIR
. "$here/versions.sh"

: "${VEYRA:?VEYRA (Wurzel des Zielsystems) setzen}"
: "${SRC:?SRC (Verzeichnis mit den Quellen) setzen}"
export VEYRA_TGT=x86_64-veyra-linux-gnu
export LC_ALL=POSIX
export PATH=$VEYRA/tools/bin:/usr/bin:/bin
export CONFIG_SITE=$VEYRA/usr/share/config.site
export MAKEFLAGS=-j${JOBS:-$(nproc)}
[ "$(id -u)" != 0 ] || { echo "Bitte nicht als root ausfuehren" >&2; exit 1; }

build=$(mktemp -d "${TMPDIR:-/tmp}/veyra-cross.XXXXXX")
trap 'rm -rf "$build"' EXIT
step() { echo; echo "=== $* ==="; }
unpack() { rm -rf "${build:?}/$2"; tar -xf "$SRC/$1" -C "$build"; cd "$build/$2"; }

# Verzeichnisstruktur des Zielsystems (usr-merge wie in LFS).
mkdir -p "$VEYRA"/{etc,var,tools,lib64} "$VEYRA"/usr/{bin,lib,sbin}
for d in bin lib sbin; do [ -e "$VEYRA/$d" ] || ln -s "usr/$d" "$VEYRA/$d"; done

step "binutils $BINUTILS_VER (Durchlauf 1)"
unpack "binutils-$BINUTILS_VER.tar.xz" "binutils-$BINUTILS_VER"
mkdir build && cd build
../configure --prefix="$VEYRA/tools" --with-sysroot="$VEYRA" --target="$VEYRA_TGT" \
  --disable-nls --enable-gprofng=no --disable-werror --enable-new-dtags \
  --enable-default-hash-style=gnu
make
make install

step "GCC $GCC_VER (Durchlauf 1)"
unpack "gcc-$GCC_VER.tar.xz" "gcc-$GCC_VER"
tar -xf "$SRC/mpfr-$MPFR_VER.tar.xz" && mv "mpfr-$MPFR_VER" mpfr
tar -xf "$SRC/gmp-$GMP_VER.tar.xz" && mv "gmp-$GMP_VER" gmp
tar -xf "$SRC/mpc-$MPC_VER.tar.gz" && mv "mpc-$MPC_VER" mpc
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir build && cd build
../configure --target="$VEYRA_TGT" --prefix="$VEYRA/tools" \
  --with-glibc-version="$GLIBC_VER" --with-sysroot="$VEYRA" --with-newlib --without-headers \
  --enable-default-pie --enable-default-ssp --disable-nls --disable-shared --disable-multilib \
  --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp \
  --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
make
make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h \
  > "$(dirname "$("$VEYRA_TGT-gcc" -print-libgcc-file-name)")/include/limits.h"

step "Linux $LINUX_VER API-Header"
unpack "linux-$LINUX_VER.tar.xz" "linux-$LINUX_VER"
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -r usr/include "$VEYRA/usr"

step "glibc $GLIBC_VER"
unpack "glibc-$GLIBC_VER.tar.xz" "glibc-$GLIBC_VER"
ln -sf ../lib/ld-linux-x86-64.so.2 "$VEYRA/lib64"
ln -sf ../lib/ld-linux-x86-64.so.2 "$VEYRA/lib64/ld-lsb-x86-64.so.3"
mkdir build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --host="$VEYRA_TGT" --build="$(../scripts/config.guess)" \
  --disable-nscd libc_cv_slibdir=/usr/lib --enable-kernel=5.4
make
make DESTDIR="$VEYRA" install
sed '/RTLDLIST=/s@/usr@@g' -i "$VEYRA/usr/bin/ldd"

step "Pruefung: Cross-Compiler linkt gegen die Veyra-glibc"
cd "$build"
echo 'int main(void){return 0;}' | "$VEYRA_TGT-gcc" -x c - -o dummy
interp=$("$VEYRA_TGT-readelf" -l dummy | grep -o 'interpreter: [^]]*' || true)
echo "   $interp"
[ "$interp" = "interpreter: /lib64/ld-linux-x86-64.so.2" ] || { echo "FEHLER: falscher Programm-Interpreter" >&2; exit 1; }

step "libstdc++ aus GCC $GCC_VER"
cd "$build/gcc-$GCC_VER"
rm -rf build-libstdc && mkdir build-libstdc && cd build-libstdc
../libstdc++-v3/configure --host="$VEYRA_TGT" --build="$(../config.guess)" --prefix=/usr \
  --disable-multilib --disable-nls --disable-libstdcxx-pch \
  --with-gxx-include-dir="/tools/$VEYRA_TGT/include/c++/$GCC_VER"
make
make DESTDIR="$VEYRA" install
rm -f "$VEYRA"/usr/lib/lib{stdc++{,exp,fs},supc++}.la

step "Pruefung: C++-Programm"
cd "$build"
printf '#include <string>\nint main(){std::string s("veyra");return s.size()==5?0:1;}\n' \
  | "$VEYRA_TGT-g++" -x c++ - -o dummy-cxx
"$VEYRA_TGT-readelf" -d dummy-cxx | grep -q 'libstdc++' || { echo "FEHLER: libstdc++ nicht gelinkt" >&2; exit 1; }

echo
echo "Cross-Toolchain fertig: $("$VEYRA_TGT-gcc" --version | head -1)"
