pkgname=texinfo
pkgver=7.2
pkgdesc="Dokumentationssystem"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/texinfo/
sources=(https://ftp.gnu.org/gnu/texinfo/texinfo-7.2.tar.xz)
sha256sums=()
depends=(glibc perl ncurses)

build() {
  cd "texinfo-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "texinfo-$pkgver"
  make DESTDIR="$pkgdir" install
}
