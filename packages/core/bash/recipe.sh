pkgname=bash
pkgver=5.3
pkgdesc="Bourne Again Shell"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/bash/
sources=(https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz)
sha256sums=()
depends=(glibc readline ncurses)

build() {
  cd "bash-$pkgver"
  ./configure --prefix=/usr --without-bash-malloc --with-installed-readline \
    --docdir="/usr/share/doc/bash-$pkgver"
  make
}

package() {
  cd "bash-$pkgver"
  make DESTDIR="$pkgdir" install
  ln -s bash "$pkgdir/usr/bin/sh"
}
