pkgname=flit-core
pkgver=3.12.0
pkgdesc="Python-Build-Backend"
license=BSD-3-Clause
url=https://github.com/pypa/flit
sources=(https://pypi.org/packages/source/f/flit-core/flit_core-3.12.0.tar.gz)
sha256sums=()
depends=(python)

build() {
  cd "flit_core-$pkgver"
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "flit_core-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist "flit_core"
}
