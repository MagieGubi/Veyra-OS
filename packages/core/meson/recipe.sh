pkgname=meson
pkgver=1.8.3
pkgdesc="Build-System Meson"
license=Apache-2.0
url=https://mesonbuild.com
sources=(https://github.com/mesonbuild/meson/releases/download/1.8.3/meson-1.8.3.tar.gz)
sha256sums=()
depends=(python ninja)

build() {
  cd "meson-$pkgver"
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
}

package() {
  cd "meson-$pkgver"
  pip3 install --root="$pkgdir" --no-index --no-deps --no-user --find-links dist "meson"
}
