pkgname=pixman
pkgver=0.46.4
pkgdesc="Pixel-Bibliothek fuer Software-Darstellung (wlroots, Schriften)"
license=MIT
url=https://pixman.org/
sources=(https://www.x.org/releases/individual/lib/pixman-0.46.4.tar.xz)
sha256sums=()
depends=(glibc)
makedepends=(meson ninja)

build() {
  cd "pixman-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D tests=disabled -D demos=disabled \
    -D gtk=disabled -D libpng=disabled
  ninja -C build
}

package() {
  cd "pixman-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
