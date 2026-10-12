pkgname=less
pkgver=679
pkgdesc="Textanzeige seitenweise"
license=GPL-3.0-or-later
url=https://www.greenwoodsoftware.com/less/
sources=(https://www.greenwoodsoftware.com/less/less-679.tar.gz)
sha256sums=()
depends=(glibc ncurses)

build() {
  cd "less-$pkgver"
  ./configure --prefix=/usr --sysconfdir=/etc
  make
}

package() {
  cd "less-$pkgver"
  make DESTDIR="$pkgdir" install
}
