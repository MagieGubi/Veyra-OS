pkgname=attr
pkgver=2.5.2
pkgdesc="Erweiterte Dateiattribute"
license=LGPL-2.1-or-later
url=https://savannah.nongnu.org/projects/attr
sources=(https://download.savannah.gnu.org/releases/attr/attr-2.5.2.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  cd "attr-$pkgver"
  ./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir="/usr/share/doc/attr-$pkgver"
  make
}

package() {
  cd "attr-$pkgver"
  make DESTDIR="$pkgdir" install
}
