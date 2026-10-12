pkgname=automake
pkgver=1.18.1
pkgdesc="Erzeugt Makefiles"
license=GPL-2.0-or-later
url=https://www.gnu.org/software/automake/
sources=(https://ftp.gnu.org/gnu/automake/automake-1.18.1.tar.xz)
sha256sums=()
depends=(perl autoconf)

build() {
  cd "automake-$pkgver"
  ./configure --prefix=/usr --docdir=/usr/share/doc/automake-$pkgver
  make
}

package() {
  cd "automake-$pkgver"
  make DESTDIR="$pkgdir" install
}
