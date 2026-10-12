pkgname=packaging
pkgver=25.0
pkgdesc="Python-Paketwerkzeuge"
license="Apache-2.0 OR BSD-2-Clause"
url=https://github.com/pypa/packaging
sources=(https://files.pythonhosted.org/packages/source/p/packaging/packaging-25.0.tar.gz)
sha256sums=()
depends=(python)

build() {
  cd "packaging-$pkgver"
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "packaging-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist "packaging"
}
