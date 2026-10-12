pkgname=xz
pkgver=5.8.1
pkgdesc="LZMA/XZ-Kompression"
license=0BSD
url=https://tukaani.org/xz/
sources=(https://github.com//tukaani-project/xz/releases/download/v5.8.1/xz-5.8.1.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "xz-$pkgver"
  ./configure --prefix=/usr --disable-static --docdir="/usr/share/doc/xz-$pkgver"
  make
}

package() {
  cd "xz-$pkgver"
  make DESTDIR="$pkgdir" install
}
