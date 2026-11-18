pkgname=ell
pkgver=0.83
pkgdesc="Embedded Linux Library (Grundlage von iwd)"
license=LGPL-2.1-or-later
url=https://git.kernel.org/pub/scm/libs/ell/ell.git
sources=(https://cdn.kernel.org/pub/linux/libs/ell/ell-0.83.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "ell-$pkgver"
  ./configure --prefix=/usr --disable-static
  make
}

package() {
  cd "ell-$pkgver"
  make DESTDIR="$pkgdir" install
}
