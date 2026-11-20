pkgname=python-mako
pkgver=1.4.3
pkgdesc="Mako-Vorlagen fuer Python (nur fuer den Bau von Mesa)"
license=MIT
url=https://www.makotemplates.org/
sources=(https://files.pythonhosted.org/packages/source/m/mako/mako-1.4.3.tar.gz)
sha256sums=()
depends=(python markupsafe)

build() {
  cd "mako-$pkgver"
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "mako-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist mako
}
