pkgname=harfbuzz
pkgver=14.2.1
pkgdesc="Textformung (Ligaturen, Schriftsysteme) fuer kitty"
license=MIT
url=https://harfbuzz.github.io/
sources=(https://github.com/harfbuzz/harfbuzz/releases/download/14.2.1/harfbuzz-14.2.1.tar.xz)
sha256sums=()
depends=(glibc gcc freetype)
makedepends=(meson ninja python)

build() {
  cd "harfbuzz-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D freetype=enabled -D glib=disabled \
    -D gobject=disabled -D cairo=disabled -D icu=disabled -D graphite2=disabled \
    -D introspection=disabled -D tests=disabled -D docs=disabled -D utilities=disabled
  ninja -C build
}

package() {
  cd "harfbuzz-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
