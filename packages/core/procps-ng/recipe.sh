pkgname=procps-ng
pkgver=4.0.5
pkgdesc="Prozessinformationen (ps, top, free)"
license=GPL-2.0-or-later
url=https://gitlab.com/procps-ng/procps
sources=(https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-4.0.5.tar.xz)
sha256sums=()
depends=(glibc ncurses systemd)

build() {
  cd "procps-ng-$pkgver"
  # watch.c nutzt bool/false und verlaesst sich darauf, dass curses.h stdbool.h einbindet;
  # das tut unser ncurses (ohne C++-Bindung gebaut) nicht. Daher explizit einbinden.
  CPPFLAGS="-include stdbool.h" ./configure --prefix=/usr --docdir=/usr/share/doc/procps-ng-$pkgver --disable-static --disable-kill --enable-watch8bit --with-systemd
  make
}

package() {
  cd "procps-ng-$pkgver"
  make DESTDIR="$pkgdir" install
}
