pkgname=libinput
pkgver=1.32.0
pkgdesc="Eingabegeraete (Tastatur, Maus, Touchpad) fuer Wayland-Compositoren"
license=MIT
url=https://wayland.freedesktop.org/libinput/doc/latest/
sources=(https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.32.0/libinput-1.32.0.tar.gz)
sha256sums=()
depends=(glibc systemd mtdev libevdev)
makedepends=(meson ninja)

build() {
  cd "libinput-$pkgver"
  # Ohne Grafiktablett-Datenbank (libwacom), Debug-Oberflaeche, Lua-Plugins und Tests.
  meson setup build --prefix=/usr --buildtype=release -D udev-dir=/usr/lib/udev \
    -D libwacom=false -D debug-gui=false -D tests=false -D documentation=false \
    -D lua-plugins=disabled
  ninja -C build
}

package() {
  cd "libinput-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
