pkgname=alsa-utils
pkgver=1.2.16
pkgdesc="ALSA-Werkzeuge: aplay, arecord, amixer, alsamixer, alsactl, speaker-test"
license=GPL-2.0-or-later
url=https://www.alsa-project.org/
sources=(https://www.alsa-project.org/files/pub/utils/alsa-utils-1.2.16.tar.bz2)
sha256sums=()
depends=(glibc alsa-lib ncurses systemd)
makedepends=()

build() {
  cd "alsa-utils-$pkgver"
  ./configure --prefix=/usr --disable-alsaconf --disable-bat --disable-xmlto --disable-rst2man \
    --with-curses=ncursesw --with-systemdsystemunitdir=/usr/lib/systemd/system \
    --with-udev-rules-dir=/usr/lib/udev/rules.d
  make
}

package() {
  cd "alsa-utils-$pkgver"
  make DESTDIR="$pkgdir" install
  install -d "$pkgdir/var/lib/alsa"
}
