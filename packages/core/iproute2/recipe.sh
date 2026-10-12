pkgname=iproute2
pkgver=6.16.0
pkgdesc="Netzwerkwerkzeuge (ip, ss)"
license=GPL-2.0-or-later
url=https://wiki.linuxfoundation.org/networking/iproute2
sources=(https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-6.16.0.tar.xz)
sha256sums=()
depends=(glibc libelf libcap)

build() {
  cd "iproute2-$pkgver"
  sed -i /ARPD/d Makefile
  rm -f man/man8/arpd.8
  make NETNS_RUN_DIR=/run/netns
}

package() {
  cd "iproute2-$pkgver"
  make SBINDIR=/usr/sbin DESTDIR="$pkgdir" install
}
