pkgname=python-pyyaml
pkgver=6.0.3
pkgdesc="YAML fuer Python, reine Python-Fassung (nur fuer den Bau von Mesa)"
license=MIT
url=https://pyyaml.org/
sources=(https://files.pythonhosted.org/packages/source/p/pyyaml/pyyaml-6.0.3.tar.gz)
sha256sums=()
depends=(python)

build() {
  cd "pyyaml-$pkgver"
  # Ohne libyaml und ohne Cython: die reine Python-Fassung reicht fuer Mesas Bau.
  PYYAML_FORCE_CYTHON=0 PYYAML_FORCE_LIBYAML=0 \
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "pyyaml-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist pyyaml
}
