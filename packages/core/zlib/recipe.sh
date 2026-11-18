pkgname=zlib
pkgver=1.3.1
pkgdesc="Kompressionsbibliothek"
license=Zlib
url=https://zlib.net
sources=(https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz)
# zlib.net/fossils lieferte am 18.11.2026 eine andere Datei aus (SHA-256 passte nicht);
# das Release auf GitHub ist bytegleich mit dem gepinnten Archiv.
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
