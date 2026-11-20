pkgname=wayland-protocols
pkgver=1.50
pkgdesc="Zusaetzliche Wayland-Protokolle (XML, nur fuer den Bau)"
license=MIT
url=https://wayland.freedesktop.org/
sources=(https://gitlab.freedesktop.org/-/project/2891/uploads/b09ec29f7a671bffbfa8896065864a04/wayland-protocols-1.50.tar.xz)
sha256sums=()
depends=()
makedepends=(meson ninja wayland)

build() {
  cd "wayland-protocols-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D tests=false
  ninja -C build
}

package() {
  cd "wayland-protocols-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
