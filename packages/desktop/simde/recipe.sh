pkgname=simde
pkgver=0.8.2
pkgdesc="SIMD-Befehle portabel (nur Header, nur fuer den Bau von kitty)"
license=MIT
url=https://simd-everywhere.github.io/blog/
sources=(https://github.com/simd-everywhere/simde/archive/refs/tags/v0.8.2.tar.gz)
sha256sums=()
depends=()

build() {
  :
}

package() {
  cd "simde-$pkgver"
  install -d "$pkgdir/usr/include"
  cp -r simde "$pkgdir/usr/include/"
  install -Dm644 COPYING "$pkgdir/usr/share/licenses/simde/COPYING"
}
