pkgname=bc
pkgver=7.0.3
pkgdesc="Rechner mit beliebiger Genauigkeit"
license=BSD-2-Clause
url=https://git.gavinhoward.com/gavin/bc
sources=(https://github.com/gavinhoward/bc/releases/download/7.0.3/bc-7.0.3.tar.xz)
sha256sums=()
depends=(glibc readline)

build() {
  cd "bc-$pkgver"
  CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
  make
}

package() {
  cd "bc-$pkgver"
  make DESTDIR="$pkgdir" install
}
