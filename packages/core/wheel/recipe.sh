pkgname=wheel
pkgver=0.46.1
pkgdesc="Python-Wheel-Format"
license=MIT
url=https://github.com/pypa/wheel
sources=(https://pypi.org/packages/source/w/wheel/wheel-0.46.1.tar.gz)
sha256sums=()
depends=(python packaging)

build() {
  cd "wheel-$pkgver"
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "wheel-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist "wheel"
}
