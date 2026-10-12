pkgname=patch
pkgver=2.8
pkgdesc="Wendet Patches an"
license=GPL-3.0-or-later
url=https://savannah.gnu.org/projects/patch/
sources=(https://ftp.gnu.org/gnu/patch/patch-2.8.tar.xz)
sha256sums=()
depends=(glibc attr)

build() {
  cd "patch-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "patch-$pkgver"
  make DESTDIR="$pkgdir" install
}
