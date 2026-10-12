pkgname=gzip
pkgver=1.14
pkgdesc="gzip-Kompression"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/gzip/
sources=(https://ftp.gnu.org/gnu/gzip/gzip-1.14.tar.xz)
sha256sums=()
depends=(glibc bash)

build() {
  cd "gzip-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "gzip-$pkgver"
  make DESTDIR="$pkgdir" install
}
