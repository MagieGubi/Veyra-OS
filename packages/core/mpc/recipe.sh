pkgname=mpc
pkgver=1.3.1
pkgdesc="Komplexe Arithmetik mit beliebiger Genauigkeit"
license=LGPL-3.0-or-later
url=https://www.multiprecision.org/mpc/
sources=(https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz)
sha256sums=()
depends=(glibc gmp mpfr)

build() {
  cd "mpc-$pkgver"
  ./configure --prefix=/usr --disable-static --docdir="/usr/share/doc/mpc-$pkgver"
  make
}

package() {
  cd "mpc-$pkgver"
  make DESTDIR="$pkgdir" install
}
