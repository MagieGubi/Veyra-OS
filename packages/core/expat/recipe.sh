pkgname=expat
pkgver=2.7.1
pkgdesc="XML-Parser-Bibliothek"
license=MIT
url=https://libexpat.github.io
sources=(https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "expat-$pkgver"
  ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/expat-$pkgver
  make
}

package() {
  cd "expat-$pkgver"
  make DESTDIR="$pkgdir" install
}
