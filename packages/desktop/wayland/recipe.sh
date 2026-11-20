pkgname=wayland
pkgver=1.26.0
pkgdesc="Wayland-Protokollbibliotheken und wayland-scanner"
license=MIT
url=https://wayland.freedesktop.org/
sources=(https://gitlab.freedesktop.org/-/project/121/uploads/5f5d2e19a230e8b8250d9a7c2f280846/wayland-1.26.0.tar.xz)
sha256sums=()
depends=(glibc libffi expat)
makedepends=(meson ninja)

build() {
  cd "wayland-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D documentation=false \
    -D dtd_validation=false -D tests=false
  ninja -C build
}

package() {
  cd "wayland-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
