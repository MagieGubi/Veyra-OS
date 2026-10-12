pkgname=lz4
pkgver=1.10.0
pkgdesc="Sehr schnelle Kompression"
license=BSD-2-Clause
url=https://lz4.org
sources=(https://github.com/lz4/lz4/releases/download/v1.10.0/lz4-1.10.0.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  cd "lz4-$pkgver"
  make BUILD_STATIC=no PREFIX=/usr
}

package() {
  cd "lz4-$pkgver"
  make BUILD_STATIC=no PREFIX=/usr DESTDIR="$pkgdir" install
}
