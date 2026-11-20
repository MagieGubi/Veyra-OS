pkgname=libxkbcommon
pkgver=1.13.2
pkgdesc="Tastaturbelegungen fuer Wayland-Programme (XKB ohne X11)"
license=MIT
url=https://xkbcommon.org/
sources=(https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-1.13.2.tar.gz)
sha256sums=()
depends=(glibc xkeyboard-config)
makedepends=(meson ninja bison wayland wayland-protocols)

build() {
  cd "libxkbcommon-xkbcommon-$pkgver"
  # Ohne X11 und ohne xkbregistry (braucht libxml2), mit den Wayland-Werkzeugen.
  meson setup build --prefix=/usr --buildtype=release -D enable-x11=false -D enable-docs=false \
    -D enable-xkbregistry=false -D enable-wayland=true -D enable-bash-completion=false
  ninja -C build
}

package() {
  cd "libxkbcommon-xkbcommon-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
