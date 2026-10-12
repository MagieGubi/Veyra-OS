pkgname=diffutils
pkgver=3.12
pkgdesc="Dateien vergleichen"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/diffutils/
sources=(https://ftp.gnu.org/gnu/diffutils/diffutils-3.12.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "diffutils-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "diffutils-$pkgver"
  make DESTDIR="$pkgdir" install
}
