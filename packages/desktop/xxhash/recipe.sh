pkgname=xxhash
pkgver=0.8.3
pkgdesc="Schnelle Pruefsummen (xxHash) fuer kitty"
license=BSD-2-Clause
url=https://xxhash.com/
sources=(https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.3.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  cd "xxHash-$pkgver"
  make PREFIX=/usr
}

package() {
  cd "xxHash-$pkgver"
  make PREFIX=/usr DESTDIR="$pkgdir" install
  rm -f "$pkgdir/usr/lib/libxxhash.a"
}
