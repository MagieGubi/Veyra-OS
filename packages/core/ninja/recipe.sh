pkgname=ninja
pkgver=1.13.1
pkgdesc="Kleines, schnelles Build-System"
license=Apache-2.0
url=https://ninja-build.org
sources=(https://github.com/ninja-build/ninja/archive/v1.13.1/ninja-1.13.1.tar.gz)
sha256sums=()
depends=(glibc gcc)

build() {
  cd "ninja-$pkgver"
  python3 configure.py --bootstrap --verbose
}

package() {
  cd "ninja-$pkgver"
  install -Dm755 ninja "$pkgdir/usr/bin/ninja"
}
