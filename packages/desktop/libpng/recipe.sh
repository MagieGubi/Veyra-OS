pkgname=libpng
pkgver=1.6.59
pkgdesc="PNG-Bilder lesen und schreiben"
license=Libpng
url=http://www.libpng.org/pub/png/libpng.html
sources=(https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.59.tar.gz)
sha256sums=()
depends=(glibc zlib)

build() {
  cd "libpng-$pkgver"
  ./configure --prefix=/usr --disable-static
  make
}

package() {
  cd "libpng-$pkgver"
  make DESTDIR="$pkgdir" install
}
