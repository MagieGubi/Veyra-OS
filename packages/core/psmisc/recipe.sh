pkgname=psmisc
pkgver=23.7
pkgdesc="Prozesswerkzeuge (killall, pstree, fuser)"
license=GPL-2.0-or-later
url=https://gitlab.com/psmisc/psmisc
sources=(https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.7.tar.xz)
sha256sums=()
depends=(glibc ncurses)

build() {
  cd "psmisc-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "psmisc-$pkgver"
  make DESTDIR="$pkgdir" install
}
