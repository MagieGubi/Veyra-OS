pkgname=wireplumber
pkgver=0.5.14
pkgdesc="WirePlumber: Sitzungs- und Richtlinienverwaltung fuer PipeWire"
license=MIT
url=https://pipewire.pages.freedesktop.org/wireplumber/
sources=(https://gitlab.freedesktop.org/pipewire/wireplumber/-/archive/0.5.14/wireplumber-0.5.14.tar.bz2)
sha256sums=()
depends=(glibc glib pipewire systemd)
makedepends=(meson ninja python lua)

build() {
  cd "wireplumber-$pkgver"
  # Systemdienst wie PipeWire (keine Benutzer-Sitzungen ohne PAM); Lua aus dem eigenen Paket.
  meson setup build --prefix=/usr --buildtype=release -D introspection=disabled -D doc=disabled \
    -D system-lua=true -D elogind=disabled -D systemd=enabled \
    -D systemd-system-service=true -D systemd-user-service=false \
    -D systemd-system-unit-dir=/usr/lib/systemd/system -D tests=false -D dbus-tests=false
  ninja -C build
}

package() {
  cd "wireplumber-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
  [ -x "$pkgdir/usr/bin/wireplumber" ] && [ -x "$pkgdir/usr/bin/wpctl" ] \
    || { echo "wireplumber oder wpctl fehlt" >&2; return 1; }
}
