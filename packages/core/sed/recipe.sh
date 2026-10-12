pkgname=sed
pkgver=4.9
pkgdesc="Stream-Editor"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/sed/
sources=(https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz)
sha256sums=()
depends=(glibc acl attr)

build() {
  cd "sed-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "sed-$pkgver"
  make DESTDIR="$pkgdir" install
}
