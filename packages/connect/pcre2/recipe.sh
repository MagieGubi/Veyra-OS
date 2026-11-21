pkgname=pcre2
pkgver=10.49
pkgdesc="Perl-kompatible regulaere Ausdruecke (fuer GLib)"
license=BSD-3-Clause
url=https://github.com/PCRE2Project/pcre2
sources=(https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.49/pcre2-10.49.tar.bz2)
sha256sums=()
depends=(glibc)
makedepends=()

build() {
  cd "pcre2-$pkgver"
  ./configure --prefix=/usr --disable-static --enable-unicode --enable-jit
  make
}

package() {
  cd "pcre2-$pkgver"
  make DESTDIR="$pkgdir" install
}
