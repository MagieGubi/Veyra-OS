pkgname=markupsafe
pkgver=3.0.2
pkgdesc="MarkupSafe (fuer Jinja2)"
license=BSD-3-Clause
url=https://palletsprojects.com/p/markupsafe/
sources=(https://pypi.org/packages/source/M/MarkupSafe/markupsafe-3.0.2.tar.gz)
sha256sums=()
depends=(python)

build() {
  cd "markupsafe-$pkgver"
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "markupsafe-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist "markupsafe"
}
