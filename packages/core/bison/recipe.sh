pkgname=bison
pkgver=3.8.2
pkgdesc="Parser-Generator"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/bison/
sources=(https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz)
sha256sums=()
depends=(glibc m4)

build() {
  cd "bison-$pkgver"
  ./configure --prefix=/usr --docdir=/usr/share/doc/bison-$pkgver
  make
}

package() {
  cd "bison-$pkgver"
  make DESTDIR="$pkgdir" install
}
