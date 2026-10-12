pkgname=autoconf
pkgver=2.72
pkgdesc="Erzeugt configure-Skripte"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/autoconf/
sources=(https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz)
sha256sums=()
depends=(perl m4)

build() {
  cd "autoconf-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "autoconf-$pkgver"
  make DESTDIR="$pkgdir" install
}
