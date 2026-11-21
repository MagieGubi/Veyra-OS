pkgname=sbc
pkgver=2.1
pkgdesc="SBC-Codec (Standard-Codec fuer Bluetooth-Audio, A2DP)"
license=LGPL-2.1-or-later
url=https://git.kernel.org/pub/scm/bluetooth/sbc.git
sources=(https://www.kernel.org/pub/linux/bluetooth/sbc-2.1.tar.xz)
sha256sums=()
depends=(glibc)
makedepends=()

build() {
  cd "sbc-$pkgver"
  ./configure --prefix=/usr --disable-static --disable-tester
  make
}

package() {
  cd "sbc-$pkgver"
  make DESTDIR="$pkgdir" install
}
