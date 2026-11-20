pkgname=lcms2
pkgver=2.19.1
pkgdesc="Farbverwaltung (ICC-Profile)"
license=MIT
url=https://www.littlecms.com/
sources=(https://github.com/mm2/Little-CMS/releases/download/lcms2.19.1/lcms2-2.19.1.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  cd "lcms2-$pkgver"
  ./configure --prefix=/usr --disable-static
  make
}

package() {
  cd "lcms2-$pkgver"
  make DESTDIR="$pkgdir" install
}
