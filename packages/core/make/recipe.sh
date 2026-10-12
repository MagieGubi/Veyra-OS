pkgname=make
pkgver=4.4.1
pkgdesc="GNU make"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/make/
sources=(https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  cd "make-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "make-$pkgver"
  make DESTDIR="$pkgdir" install
}
