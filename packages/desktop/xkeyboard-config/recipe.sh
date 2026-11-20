pkgname=xkeyboard-config
pkgver=2.48
pkgdesc="Tastaturbelegungen (XKB-Daten, auch fuer Wayland)"
license=MIT
url=https://www.freedesktop.org/wiki/Software/XKeyboardConfig/
sources=(https://www.x.org/releases/individual/data/xkeyboard-config/xkeyboard-config-2.48.tar.xz)
sha256sums=()
depends=()
makedepends=(meson ninja python)

build() {
  cd "xkeyboard-config-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D xorg-rules-symlinks=true
  ninja -C build
}

package() {
  cd "xkeyboard-config-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
