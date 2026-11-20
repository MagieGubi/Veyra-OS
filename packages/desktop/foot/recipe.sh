pkgname=foot
pkgver=1.28.0
pkgdesc="Schlankes Wayland-Terminal (ohne OpenGL; Uebergang, bis kitty mit Mesa laeuft)"
license=MIT
url=https://codeberg.org/dnkl/foot
sources=(https://codeberg.org/dnkl/foot/releases/download/1.28.0/foot-1.28.0.tar.gz)
sha256sums=()
depends=(glibc wayland libxkbcommon pixman fontconfig fcft dejavu-fonts)
makedepends=(meson ninja wayland-protocols tllist ncurses)

build() {
  cd "foot-$pkgver"
  meson setup build --prefix=/usr --sysconfdir=/etc --buildtype=release -D docs=disabled \
    -D grapheme-clustering=disabled -D tests=false -D terminfo=enabled
  ninja -C build
}

package() {
  cd "foot-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
