pkgname=cairo
pkgver=1.18.4
pkgdesc="2D-Grafik (fuer kitty)"
license="LGPL-2.1-only OR MPL-1.1"
url=https://cairographics.org/
sources=(https://gitlab.freedesktop.org/cairo/cairo/-/archive/1.18.4/cairo-1.18.4.tar.bz2)
sha256sums=()
depends=(glibc pixman freetype fontconfig libpng zlib)
makedepends=(meson ninja)

build() {
  cd "cairo-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D xlib=disabled -D xcb=disabled \
    -D png=enabled -D freetype=enabled -D fontconfig=enabled -D glib=disabled -D tests=disabled \
    -D spectre=disabled -D symbol-lookup=disabled -D gtk_doc=false -D lzo=disabled -D zlib=enabled
  ninja -C build
}

package() {
  cd "cairo-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
