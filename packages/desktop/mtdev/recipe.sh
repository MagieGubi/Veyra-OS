pkgname=mtdev
pkgver=1.1.7
pkgdesc="Mehrfingereingaben (Multitouch) fuer libinput"
license=MIT
url=https://bitmath.org/code/mtdev/
sources=(https://bitmath.org/code/mtdev/mtdev-1.1.7.tar.bz2)
sha256sums=()
depends=(glibc)

build() {
  cd "mtdev-$pkgver"
  ./configure --prefix=/usr --disable-static
  make
}

package() {
  cd "mtdev-$pkgver"
  make DESTDIR="$pkgdir" install
}
