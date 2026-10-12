pkgname=libffi
pkgver=3.5.2
pkgdesc="Foreign Function Interface"
license=MIT
url=https://sourceware.org/libffi/
sources=(https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  cd "libffi-$pkgver"
  # x86-64 statt native: das Paket soll auf jeder x86_64-CPU laufen, nicht nur auf dem CI-Rechner
  ./configure --prefix=/usr --disable-static --with-gcc-arch=x86-64
  make
}

package() {
  cd "libffi-$pkgver"
  make DESTDIR="$pkgdir" install
}
