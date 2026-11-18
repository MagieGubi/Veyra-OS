pkgname=libmnl
pkgver=1.0.5
pkgdesc="Kleine Bibliothek fuer Netlink (Grundlage von nftables)"
license=LGPL-2.1-or-later
url=https://www.netfilter.org/projects/libmnl/
sources=(https://www.netfilter.org/pub/libmnl/libmnl-1.0.5.tar.bz2)
sha256sums=()
depends=(glibc)

build() {
  cd "libmnl-$pkgver"
  ./configure --prefix=/usr --disable-static
  make
}

package() {
  cd "libmnl-$pkgver"
  make DESTDIR="$pkgdir" install
}
