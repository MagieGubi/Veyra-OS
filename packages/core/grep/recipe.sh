pkgname=grep
pkgver=3.12
pkgdesc="Textsuche"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/grep/
sources=(https://ftp.gnu.org/gnu/grep/grep-3.12.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "grep-$pkgver"
  sed -i "s/echo/#echo/" src/egrep.sh
  ./configure --prefix=/usr
  make
}

package() {
  cd "grep-$pkgver"
  make DESTDIR="$pkgdir" install
}
