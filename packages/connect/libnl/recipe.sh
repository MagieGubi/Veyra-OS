pkgname=libnl
pkgver=3.12.0
pkgdesc="Netlink-Bibliotheken (libnl-3, libnl-genl-3) fuer nl80211"
license=LGPL-2.1-or-later
url=https://github.com/thom311/libnl
sources=(https://github.com/thom311/libnl/releases/download/libnl3_12_0/libnl-3.12.0.tar.gz)
sha256sums=()
depends=(glibc)
makedepends=()

build() {
  cd "libnl-$pkgver"
  ./configure --prefix=/usr --sysconfdir=/etc --disable-static --enable-cli=no
  make
}

package() {
  cd "libnl-$pkgver"
  make DESTDIR="$pkgdir" install
}
