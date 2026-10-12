pkgname=jinja2
pkgver=3.1.6
pkgdesc="Jinja2-Vorlagen (fuer den systemd-Build)"
license=BSD-3-Clause
url=https://palletsprojects.com/p/jinja/
sources=(https://pypi.org/packages/source/J/Jinja2/jinja2-3.1.6.tar.gz)
sha256sums=()
depends=(python markupsafe)

build() {
  cd "jinja2-$pkgver"
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "jinja2-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist "jinja2"
}
