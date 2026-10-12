pkgname=dbus
pkgver=1.16.2
pkgdesc="Nachrichtenbus zwischen Programmen"
license="AFL-2.1 OR GPL-2.0-or-later"
url=https://www.freedesktop.org/wiki/Software/dbus/
sources=(https://dbus.freedesktop.org/releases/dbus/dbus-1.16.2.tar.xz)
sha256sums=()
depends=(glibc expat systemd)

build() {
  cd "dbus-$pkgver"
  mkdir build && cd build
  meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
  ninja
}

package() {
  cd "dbus-$pkgver/build"
  DESTDIR="$pkgdir" ninja install
  mkdir -p "$pkgdir/var/lib/dbus"
  ln -sf /etc/machine-id "$pkgdir/var/lib/dbus/machine-id"
}
