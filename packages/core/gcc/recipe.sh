pkgname=gcc
pkgver=15.2.0
pkgdesc="GNU Compiler Collection (C und C++)"
license=GPL-3.0-or-later
url=https://gcc.gnu.org
sources=(https://ftp.gnu.org/gnu/gcc/gcc-15.2.0/gcc-15.2.0.tar.xz)
sha256sums=()
depends=(glibc binutils gmp mpfr mpc zlib zstd)

build() {
  cd "gcc-$pkgver"
  sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  mkdir build && cd build
  ../configure --prefix=/usr LD=ld --enable-languages=c,c++ --enable-default-pie --enable-default-ssp \
    --enable-host-pie --disable-multilib --disable-bootstrap --disable-fixincludes --with-system-zlib
  make
}

package() {
  cd "gcc-$pkgver/build"
  make DESTDIR="$pkgdir" install
  tgt=$(sh ../config.guess)
  chown -R root:root "$pkgdir/usr/lib/gcc/$tgt/$pkgver/include"{,-fixed}
  ln -sr "$pkgdir/usr/bin/cpp" "$pkgdir/usr/lib"
  ln -s gcc.1 "$pkgdir/usr/share/man/man1/cc.1"
  ln -s gcc "$pkgdir/usr/bin/cc"
  mkdir -p "$pkgdir/usr/lib/bfd-plugins"
  ln -sf "../../libexec/gcc/$tgt/$pkgver/liblto_plugin.so" "$pkgdir/usr/lib/bfd-plugins/"
  mkdir -p "$pkgdir/usr/share/gdb/auto-load/usr/lib"
  mv "$pkgdir"/usr/lib/*gdb.py "$pkgdir/usr/share/gdb/auto-load/usr/lib"
}

# Pruefung wie in LFS 8.29: der neue Compiler linkt gegen die neue glibc mit dem richtigen Interpreter.
post_install() {
  t=$(mktemp -d)
  echo 'int main(void){return 0;}' > "$t/d.c"
  cc "$t/d.c" -v -Wl,--verbose -o "$t/d" &> "$t/d.log"
  readelf -l "$t/d" | grep -q 'Requesting program interpreter: /lib64/ld-linux-x86-64.so.2' \
    || { echo "gcc: falscher Programm-Interpreter" >&2; exit 1; }
  grep -q 'succeeded' "$t/d.log" || { echo "gcc: Startdateien nicht gefunden" >&2; exit 1; }
  if grep -q '/tools' "$t/d.log"; then echo "gcc: verweist noch auf /tools" >&2; exit 1; fi
  "$t/d"
  rm -rf "$t"
  echo "   gcc-Pruefung ok"
}
