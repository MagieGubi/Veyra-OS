pkgname=ncurses
pkgver=6.5
pkgdesc="Terminal-Bibliothek"
license=MIT
url=https://invisible-island.net/ncurses/
sources=(https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  cd "ncurses-$pkgver"
  # Ohne C++-Bindung: ncurses 6.5 (Release) baut sie mit GCC 15 nicht (siehe Stufe 3).
  ./configure --prefix=/usr --mandir=/usr/share/man --with-shared --without-debug --without-normal \
    --without-cxx-binding --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig
  make
}

package() {
  cd "ncurses-$pkgver"
  make DESTDIR="$pkgdir" install
  sed -e 's/^#if.*XOPEN.*$/#if 1/' -i "$pkgdir/usr/include/curses.h"
  for lib in ncurses form panel menu; do
    ln -sf "lib${lib}w.so" "$pkgdir/usr/lib/lib${lib}.so"
    ln -sf "${lib}w.pc" "$pkgdir/usr/lib/pkgconfig/${lib}.pc"
  done
  ln -sf libncursesw.so "$pkgdir/usr/lib/libcurses.so"
}
