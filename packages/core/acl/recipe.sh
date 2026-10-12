pkgname=acl
pkgver=2.3.2
pkgdesc="Zugriffssteuerungslisten (POSIX ACL)"
license=LGPL-2.1-or-later
url=https://savannah.nongnu.org/projects/acl
sources=(https://download.savannah.gnu.org/releases/acl/acl-2.3.2.tar.xz)
sha256sums=()
depends=(glibc attr)

build() {
  cd "acl-$pkgver"
  ./configure --prefix=/usr --disable-static --docdir="/usr/share/doc/acl-$pkgver"
  make
}

package() {
  cd "acl-$pkgver"
  make DESTDIR="$pkgdir" install
}
