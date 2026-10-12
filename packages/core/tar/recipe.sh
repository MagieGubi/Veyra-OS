pkgname=tar
pkgver=1.35
pkgdesc="GNU tar"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/tar/
sources=(https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz)
sha256sums=()
depends=(glibc acl attr)

build() {
  cd "tar-$pkgver"
  FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
  make
}

package() {
  cd "tar-$pkgver"
  make DESTDIR="$pkgdir" install
}
