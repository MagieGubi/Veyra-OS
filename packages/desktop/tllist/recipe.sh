pkgname=tllist
pkgver=1.1.0
pkgdesc="Listen-Makros in C (nur fuer den Bau von fcft und foot)"
license=MIT
url=https://codeberg.org/dnkl/tllist
sources=(https://codeberg.org/dnkl/tllist/releases/download/1.1.0/tllist-1.1.0.tar.gz)
sha256sums=()
depends=()
makedepends=(meson ninja)

build() {
  cd "tllist-$pkgver"
  meson setup build --prefix=/usr --buildtype=release
  ninja -C build
}

package() {
  cd "tllist-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
