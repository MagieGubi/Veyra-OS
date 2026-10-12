pkgname=zlib
pkgver=1.3.1
pkgdesc="Kompressionsbibliothek"
license=Zlib
url=https://zlib.net
sources=(https://zlib.net/fossils/zlib-1.3.1.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  cd "zlib-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "zlib-$pkgver"
  make DESTDIR="$pkgdir" install
  rm -f "$pkgdir/usr/lib/libz.a"
}
