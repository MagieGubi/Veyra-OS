pkgname=gawk
pkgver=5.3.2
pkgdesc="GNU awk"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/gawk/
sources=(https://ftp.gnu.org/gnu/gawk/gawk-5.3.2.tar.xz)
sha256sums=()
depends=(glibc readline gmp mpfr)

build() {
  cd "gawk-$pkgver"
  sed -i 's/extras//' Makefile.in
  ./configure --prefix=/usr
  make
}

package() {
  cd "gawk-$pkgver"
  make DESTDIR="$pkgdir" install
  rm -f "$pkgdir/usr/bin/gawk-$pkgver"
  ln -sf gawk.1 "$pkgdir/usr/share/man/man1/awk.1"
}
