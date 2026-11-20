pkgname=libdisplay-info
pkgver=0.3.0
pkgdesc="Liest EDID und DisplayID von Bildschirmen"
license=MIT
url=https://gitlab.freedesktop.org/emersion/libdisplay-info
sources=(https://gitlab.freedesktop.org/-/project/14497/uploads/a7e427e2c5ef474032a87459443b7982/libdisplay-info-0.3.0.tar.xz)
sha256sums=()
depends=(glibc)
makedepends=(meson ninja hwdata python)

build() {
  cd "libdisplay-info-$pkgver"
  meson setup build --prefix=/usr --buildtype=release
  ninja -C build
}

package() {
  cd "libdisplay-info-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
