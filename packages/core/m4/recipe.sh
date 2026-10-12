pkgname=m4
pkgver=1.4.20
pkgdesc="Makroprozessor"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/m4/
sources=(https://ftp.gnu.org/gnu/m4/m4-1.4.20.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "m4-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "m4-$pkgver"
  make DESTDIR="$pkgdir" install
}
