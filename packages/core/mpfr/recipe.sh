pkgname=mpfr
pkgver=4.2.2
pkgdesc="Gleitkomma-Arithmetik mit beliebiger Genauigkeit"
license=LGPL-3.0-or-later
url=https://www.mpfr.org
sources=(https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.2.tar.xz)
sha256sums=()
depends=(glibc gmp)

build() {
  cd "mpfr-$pkgver"
  ./configure --prefix=/usr --disable-static --enable-thread-safe --docdir="/usr/share/doc/mpfr-$pkgver"
  make
}

package() {
  cd "mpfr-$pkgver"
  make DESTDIR="$pkgdir" install
}
