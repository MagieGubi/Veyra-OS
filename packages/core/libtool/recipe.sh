pkgname=libtool
pkgver=2.5.4
pkgdesc="Generisches Werkzeug fuer gemeinsame Bibliotheken"
license=GPL-2.0-or-later
url=https://www.gnu.org/software/libtool/
sources=(https://ftp.gnu.org/gnu/libtool/libtool-2.5.4.tar.xz)
sha256sums=()
depends=(glibc bash)

build() {
  cd "libtool-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "libtool-$pkgver"
  make DESTDIR="$pkgdir" install
  rm -f "$pkgdir/usr/lib/libltdl.a"
}
