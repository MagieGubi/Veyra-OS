pkgname=setuptools
pkgver=80.9.0
pkgdesc="Python-Setuptools"
license=MIT
url=https://github.com/pypa/setuptools
sources=(https://pypi.org/packages/source/s/setuptools/setuptools-80.9.0.tar.gz)
sha256sums=()
depends=(python)

build() {
  cd "setuptools-$pkgver"
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "setuptools-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist "setuptools"
}
