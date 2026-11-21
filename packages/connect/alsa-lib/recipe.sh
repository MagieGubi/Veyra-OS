pkgname=alsa-lib
pkgver=1.2.16.1
pkgdesc="ALSA-Bibliothek (Zugriff auf Soundkarten)"
license=LGPL-2.1-or-later
url=https://www.alsa-project.org/
sources=(https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.16.1.tar.bz2)
sha256sums=()
depends=(glibc)
makedepends=()

build() {
  cd "alsa-lib-$pkgver"
  ./configure --prefix=/usr --disable-static --without-debug
  make
}

package() {
  cd "alsa-lib-$pkgver"
  make DESTDIR="$pkgdir" install
}
