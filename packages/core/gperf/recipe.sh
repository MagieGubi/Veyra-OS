pkgname=gperf
pkgver=3.3
pkgdesc="Generator fuer perfekte Hash-Funktionen"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/gperf/
sources=(https://ftp.gnu.org/gnu/gperf/gperf-3.3.tar.gz)
sha256sums=()
depends=(glibc gcc)

build() {
  cd "gperf-$pkgver"
  ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-$pkgver
  make
}

package() {
  cd "gperf-$pkgver"
  make DESTDIR="$pkgdir" install
}
