pkgname=file
pkgver=5.46
pkgdesc="Erkennt Dateitypen"
license=BSD-2-Clause
url=https://www.darwinsys.com/file/
sources=(https://astron.com/pub/file/file-5.46.tar.gz)
sha256sums=()
depends=(glibc zlib bzip2 xz zstd)

build() {
  cd "file-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "file-$pkgver"
  make DESTDIR="$pkgdir" install
}
