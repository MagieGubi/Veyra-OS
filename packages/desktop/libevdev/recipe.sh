pkgname=libevdev
pkgver=1.14.0
pkgdesc="Eingabegeraete ueber evdev"
license=MIT
url=https://www.freedesktop.org/wiki/Software/libevdev/
sources=(https://www.freedesktop.org/software/libevdev/libevdev-1.14.0.tar.xz)
sha256sums=()
depends=(glibc)
makedepends=(meson ninja python)

build() {
  cd "libevdev-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D tests=disabled -D documentation=disabled
  ninja -C build
}

package() {
  cd "libevdev-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
