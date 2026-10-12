pkgname=findutils
pkgver=4.10.0
pkgdesc="Dateien suchen"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/findutils/
sources=(https://ftp.gnu.org/gnu/findutils/findutils-4.10.0.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "findutils-$pkgver"
  ./configure --prefix=/usr --localstatedir=/var/lib/locate
  make
}

package() {
  cd "findutils-$pkgver"
  make DESTDIR="$pkgdir" install
}
