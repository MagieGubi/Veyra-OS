pkgname=util-linux
pkgver=2.41.1
pkgdesc="Systemwerkzeuge (mount, fdisk, lsblk ...)"
license=GPL-2.0-or-later
url=https://github.com/util-linux/util-linux
sources=(https://www.kernel.org/pub/linux/utils/util-linux/v2.41/util-linux-2.41.1.tar.xz)
sha256sums=()
depends=(glibc ncurses zlib libcap libxcrypt systemd)

build() {
  cd "util-linux-$pkgver"
  ./configure --bindir=/usr/bin --libdir=/usr/lib --runstatedir=/run --sbindir=/usr/sbin \
    --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv \
    --disable-runuser --disable-pylibmount --disable-liblastlog2 --disable-static --without-python \
    ADJTIME_PATH=/var/lib/hwclock/adjtime --docdir="/usr/share/doc/util-linux-$pkgver"
  make
}

package() {
  cd "util-linux-$pkgver"
  make DESTDIR="$pkgdir" install
}
