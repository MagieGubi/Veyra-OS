pkgname=libnftnl
pkgver=1.2.9
pkgdesc="Netlink-Schnittstelle zu nf_tables im Kernel"
license=GPL-2.0-or-later
url=https://www.netfilter.org/projects/libnftnl/
sources=(https://www.netfilter.org/pub/libnftnl/libnftnl-1.2.9.tar.xz)
sha256sums=()
depends=(glibc libmnl)

build() {
  cd "libnftnl-$pkgver"
  ./configure --prefix=/usr --disable-static
  make
}

package() {
  cd "libnftnl-$pkgver"
  make DESTDIR="$pkgdir" install
}
