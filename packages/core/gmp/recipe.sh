pkgname=gmp
pkgver=6.3.0
pkgdesc="Arithmetik mit beliebiger Genauigkeit"
license=LGPL-3.0-or-later
url=https://gmplib.org
sources=(https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "gmp-$pkgver"
  sed -i '/long long t1;/,+1s/()/(...)/' configure
  # --host=none-linux-gnu: generische Bibliothek statt Optimierung auf die CPU des Build-Rechners
  ./configure --prefix=/usr --enable-cxx --disable-static --docdir="/usr/share/doc/gmp-$pkgver" \
    --host=none-linux-gnu
  make
}

package() {
  cd "gmp-$pkgver"
  make DESTDIR="$pkgdir" install
}
