pkgname=zstd
pkgver=1.5.7
pkgdesc="Zstandard-Kompression"
license=BSD-3-Clause
url=https://facebook.github.io/zstd/
sources=(https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz)
sha256sums=()
depends=(glibc zlib xz lz4)

build() {
  cd "zstd-$pkgver"
  make prefix=/usr
}

package() {
  cd "zstd-$pkgver"
  make prefix=/usr DESTDIR="$pkgdir" install
  rm -f "$pkgdir/usr/lib/libzstd.a"
}
