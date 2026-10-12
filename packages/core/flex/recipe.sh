pkgname=flex
pkgver=2.6.4
pkgdesc="Scanner-Generator"
license=BSD-2-Clause
url=https://github.com/westes/flex
sources=(https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz)
sha256sums=()
depends=(glibc m4)

build() {
  cd "flex-$pkgver"
  ./configure --prefix=/usr --docdir="/usr/share/doc/flex-$pkgver" --disable-static
  make
}

package() {
  cd "flex-$pkgver"
  make DESTDIR="$pkgdir" install
  ln -s flex "$pkgdir/usr/bin/lex"
  ln -s flex.1 "$pkgdir/usr/share/man/man1/lex.1"
}
