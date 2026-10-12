pkgname=readline
pkgver=8.3
pkgdesc="Zeileneditor-Bibliothek"
license=GPL-3.0-or-later
url=https://tiswww.case.edu/php/chet/readline/rltop.html
sources=(https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz)
sha256sums=()
depends=(glibc ncurses)

build() {
  cd "readline-$pkgver"
  sed -i '/MV.*old/d' Makefile.in
  sed -i '/{OLDSUFF}/c:' support/shlib-install
  sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
  ./configure --prefix=/usr --disable-static --with-curses --docdir="/usr/share/doc/readline-$pkgver"
  make SHLIB_LIBS="-lncursesw"
}

package() {
  cd "readline-$pkgver"
  make SHLIB_LIBS="-lncursesw" DESTDIR="$pkgdir" install
}
