pkgname=cage
pkgver=0.3.1
pkgdesc="Kiosk-Compositor: zeigt ein einziges Programm bildschirmfuellend"
license=MIT
url=https://github.com/cage-kiosk/cage
sources=(https://github.com/cage-kiosk/cage/releases/download/v0.3.1/cage-0.3.1.tar.gz)
sha256sums=()
depends=(glibc wlroots wayland libxkbcommon)
makedepends=(meson ninja wayland-protocols)

build() {
  cd "cage-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D man-pages=disabled
  ninja -C build
}

package() {
  cd "cage-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
