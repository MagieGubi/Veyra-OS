#!/usr/bin/env bash
# Stufe 3: temporaere Werkzeuge fuer das Veyra-Zielsystem.
#
# Baut nach der Methode von Linux From Scratch 12.4 (Kapitel 6) mit der Cross-Toolchain aus Stufe 2:
#   m4, ncurses, bash, coreutils, diffutils, file, findutils, gawk, grep, gzip, make, patch,
#   sed, tar, xz, binutils (Durchlauf 2), GCC (Durchlauf 2)
# Danach enthaelt $VEYRA genug, um in einer chroot-Umgebung weiterzubauen (Stufe 4).
#
# Aufruf (als normaler Nutzer, nicht root, nach toolchain/build-cross.sh):
#   VEYRA=/veyra SRC=/sources temptools/build-temp.sh
set -euo pipefail
set +h
umask 022

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=versions.sh source-path=SCRIPTDIR
. "$here/versions.sh"
# shellcheck source=../toolchain/versions.sh source-path=SCRIPTDIR
. "$here/../toolchain/versions.sh"

: "${VEYRA:?VEYRA (Wurzel des Zielsystems) setzen}"
: "${SRC:?SRC (Verzeichnis mit den Quellen) setzen}"
export VEYRA_TGT=x86_64-veyra-linux-gnu
export LC_ALL=POSIX
export PATH=$VEYRA/tools/bin:/usr/bin:/bin
export CONFIG_SITE=$VEYRA/usr/share/config.site
export MAKEFLAGS=-j${JOBS:-$(nproc)}
[ "$(id -u)" != 0 ] || { echo "Bitte nicht als root ausfuehren" >&2; exit 1; }
[ -x "$VEYRA/tools/bin/$VEYRA_TGT-gcc" ] || { echo "Cross-Toolchain (Stufe 2) fehlt in $VEYRA/tools" >&2; exit 1; }

build=$(mktemp -d "${TMPDIR:-/tmp}/veyra-temp.XXXXXX")
trap 'rm -rf "$build"' EXIT
step() { echo; echo "=== $* ==="; }
unpack() { rm -rf "${build:?}/$2"; tar -xf "$SRC/$1" -C "$build"; cd "$build/$2"; }
# Standardfall: autoconf-Paket mit build-aux/config.guess, Installation nach $VEYRA.
simple() {
  unpack "$1" "$2"
  shift 2
  ./configure --prefix=/usr --host="$VEYRA_TGT" --build="$(build-aux/config.guess)" "$@"
  make
  make DESTDIR="$VEYRA" install
}

step "m4 $M4_VER"
simple "m4-$M4_VER.tar.xz" "m4-$M4_VER"

step "ncurses $NCURSES_VER"
# Ohne C++-Bindung: ncurses 6.5 (Release) erkennt mit GCC 15 die Groesse von bool falsch,
# die C++-Bindung bricht dann ab. Stufe 3 braucht sie nicht; das endgueltige ncurses kommt in Stufe 4.
unpack "ncurses-$NCURSES_VER.tar.gz" "ncurses-$NCURSES_VER"
mkdir build
pushd build >/dev/null
  ../configure --prefix="$VEYRA/tools" AWK=gawk
  make -C include
  make -C progs tic
  install progs/tic "$VEYRA/tools/bin"
popd >/dev/null
./configure --prefix=/usr --host="$VEYRA_TGT" --build="$(./config.guess)" \
  --mandir=/usr/share/man --with-manpage-format=normal --with-shared --without-normal \
  --without-cxx-binding --without-debug --without-ada --disable-stripping AWK=gawk
make
make DESTDIR="$VEYRA" install
ln -sf libncursesw.so "$VEYRA/usr/lib/libncurses.so"
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i "$VEYRA/usr/include/curses.h"

step "bash $BASH_VER"
unpack "bash-$BASH_VER.tar.gz" "bash-$BASH_VER"
./configure --prefix=/usr --build="$(sh support/config.guess)" --host="$VEYRA_TGT" --without-bash-malloc
make
make DESTDIR="$VEYRA" install
ln -sf bash "$VEYRA/bin/sh"

step "coreutils $COREUTILS_VER"
simple "coreutils-$COREUTILS_VER.tar.xz" "coreutils-$COREUTILS_VER" \
  --enable-install-program=hostname --enable-no-install-program=kill,uptime
mv "$VEYRA/usr/bin/chroot" "$VEYRA/usr/sbin"
mkdir -p "$VEYRA/usr/share/man/man8"
mv "$VEYRA/usr/share/man/man1/chroot.1" "$VEYRA/usr/share/man/man8/chroot.8"
sed -i 's/"1"/"8"/' "$VEYRA/usr/share/man/man8/chroot.8"

step "diffutils $DIFFUTILS_VER"
simple "diffutils-$DIFFUTILS_VER.tar.xz" "diffutils-$DIFFUTILS_VER" gl_cv_func_strcasecmp_works=y

step "file $FILE_VER"
unpack "file-$FILE_VER.tar.gz" "file-$FILE_VER"
mkdir build
pushd build >/dev/null
  ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
  make
popd >/dev/null
./configure --prefix=/usr --host="$VEYRA_TGT" --build="$(./config.guess)"
make FILE_COMPILE="$(pwd)/build/src/file"
make DESTDIR="$VEYRA" install
rm -f "$VEYRA/usr/lib/libmagic.la"

step "findutils $FINDUTILS_VER"
simple "findutils-$FINDUTILS_VER.tar.xz" "findutils-$FINDUTILS_VER" --localstatedir=/var/lib/locate

step "gawk $GAWK_VER"
unpack "gawk-$GAWK_VER.tar.xz" "gawk-$GAWK_VER"
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr --host="$VEYRA_TGT" --build="$(build-aux/config.guess)"
make
make DESTDIR="$VEYRA" install

step "grep $GREP_VER"
simple "grep-$GREP_VER.tar.xz" "grep-$GREP_VER"

step "gzip $GZIP_VER"
unpack "gzip-$GZIP_VER.tar.xz" "gzip-$GZIP_VER"
./configure --prefix=/usr --host="$VEYRA_TGT"
make
make DESTDIR="$VEYRA" install

step "make $MAKE_VER"
simple "make-$MAKE_VER.tar.gz" "make-$MAKE_VER"

step "patch $PATCH_VER"
simple "patch-$PATCH_VER.tar.xz" "patch-$PATCH_VER"

step "sed $SED_VER"
simple "sed-$SED_VER.tar.xz" "sed-$SED_VER"

step "tar $TAR_VER"
simple "tar-$TAR_VER.tar.xz" "tar-$TAR_VER"

step "xz $XZ_VER"
simple "xz-$XZ_VER.tar.xz" "xz-$XZ_VER" --disable-static --docdir="/usr/share/doc/xz-$XZ_VER"
rm -f "$VEYRA/usr/lib/liblzma.la"

step "binutils $BINUTILS_VER (Durchlauf 2)"
unpack "binutils-$BINUTILS_VER.tar.xz" "binutils-$BINUTILS_VER"
# shellcheck disable=SC2016 # $add_dir ist Text in ltmain.sh, keine Shell-Variable
sed '6031s/$add_dir//' -i ltmain.sh
mkdir build && cd build
../configure --prefix=/usr --build="$(../config.guess)" --host="$VEYRA_TGT" \
  --disable-nls --enable-shared --enable-gprofng=no --disable-werror --enable-64-bit-bfd \
  --enable-new-dtags --enable-default-hash-style=gnu
make
make DESTDIR="$VEYRA" install
rm -f "$VEYRA"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

step "GCC $GCC_VER (Durchlauf 2)"
unpack "gcc-$GCC_VER.tar.xz" "gcc-$GCC_VER"
tar -xf "$SRC/mpfr-$MPFR_VER.tar.xz" && mv "mpfr-$MPFR_VER" mpfr
tar -xf "$SRC/gmp-$GMP_VER.tar.xz" && mv "gmp-$GMP_VER" gmp
tar -xf "$SRC/mpc-$MPC_VER.tar.gz" && mv "mpc-$MPC_VER" mpc
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
mkdir build && cd build
../configure --build="$(../config.guess)" --host="$VEYRA_TGT" --target="$VEYRA_TGT" \
  --prefix=/usr --with-build-sysroot="$VEYRA" --enable-default-pie --enable-default-ssp \
  --disable-nls --disable-multilib --disable-libatomic --disable-libgomp --disable-libquadmath \
  --disable-libsanitizer --disable-libssp --disable-libvtv --enable-languages=c,c++ \
  LDFLAGS_FOR_TARGET="-L$PWD/$VEYRA_TGT/libgcc"
make
make DESTDIR="$VEYRA" install
ln -sf gcc "$VEYRA/usr/bin/cc"

step "Pruefung: Werkzeuge sind fuer das Zielsystem gebaut"
for f in usr/bin/bash usr/bin/ls usr/bin/make usr/bin/gcc usr/bin/ld usr/bin/tar; do
  [ -x "$VEYRA/$f" ] || { echo "FEHLER: $f fehlt" >&2; exit 1; }
  interp=$("$VEYRA_TGT-readelf" -l "$VEYRA/$f" | grep -o 'interpreter: [^]]*' || true)
  [ "$interp" = "interpreter: /lib64/ld-linux-x86-64.so.2" ] \
    || { echo "FEHLER: $f hat falschen Interpreter: $interp" >&2; exit 1; }
  echo "   ok $f"
done

echo
echo "Temporaere Werkzeuge fertig. Naechster Schritt: chroot in $VEYRA (Stufe 4)."
