pkgname=iwd
pkgver=3.12
pkgdesc="WLAN-Dienst (WPA2, WPA3) mit iwctl"
license=LGPL-2.1-or-later
url=https://iwd.wiki.kernel.org/
sources=(https://cdn.kernel.org/pub/linux/network/wireless/iwd-3.12.tar.xz)
sha256sums=()
depends=(glibc ell dbus readline)

build() {
  cd "iwd-$pkgver"
  # Externe ell (eigenes Paket), keine Handbuchseiten (braucht rst2man). IP-Adressen
  # vergibt systemd-networkd (veyra-wlan), nicht iwd selbst.
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libexecdir=/usr/lib/iwd \
    --enable-external-ell --disable-manual-pages \
    --with-systemd-unitdir=/usr/lib/systemd/system \
    --with-dbus-datadir=/usr/share --with-dbus-busdir=/usr/share/dbus-1/system-services
  make
}

package() {
  cd "iwd-$pkgver"
  make DESTDIR="$pkgdir" install
}
