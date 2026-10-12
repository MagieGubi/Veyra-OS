pkgname=gdbm
pkgver=1.26
pkgdesc="GNU-Datenbankbibliothek"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/gdbm/
sources=(https://ftp.gnu.org/gnu/gdbm/gdbm-1.26.tar.gz)
sha256sums=()
depends=(glibc readline)

build() {
  cd "gdbm-$pkgver"
  ./configure --prefix=/usr --disable-static --enable-libgdbm-compat
  make
}

package() {
  cd "gdbm-$pkgver"
  make DESTDIR="$pkgdir" install
}
