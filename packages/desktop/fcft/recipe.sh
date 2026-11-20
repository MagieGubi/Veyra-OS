pkgname=fcft
pkgver=3.3.3
pkgdesc="Schriften laden und mit pixman darstellen (fuer foot)"
license=MIT
url=https://codeberg.org/dnkl/fcft
sources=(https://codeberg.org/dnkl/fcft/releases/download/3.3.3/fcft-3.3.3.tar.gz)
sha256sums=()
depends=(glibc freetype fontconfig pixman)
makedepends=(meson ninja tllist)

build() {
  cd "fcft-$pkgver"
  meson setup build --prefix=/usr --buildtype=release -D docs=disabled \
    -D grapheme-shaping=disabled -D run-shaping=disabled -D test-text-shaping=false
  ninja -C build
}

package() {
  cd "fcft-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
