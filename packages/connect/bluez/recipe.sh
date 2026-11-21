pkgname=bluez
pkgver=5.87
pkgdesc="BlueZ: Bluetooth-Dienst (bluetoothd) und Werkzeuge (bluetoothctl, btmon)"
license=GPL-2.0-or-later
url=https://www.bluez.org/
sources=(https://www.kernel.org/pub/linux/bluetooth/bluez-5.87.tar.xz)
sha256sums=()
depends=(glibc glib dbus systemd readline)
makedepends=()

build() {
  cd "bluez-$pkgver"
  # Ohne OBEX (Dateiuebertragung, braeuchte libical), CUPS und Mesh; ohne Handbuchseiten
  # (braeuchten rst2man). --enable-testing baut den Controller-Emulator btvirt fuer den
  # QEMU-Test mit virtuellen Controllern (hci_vhci).
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libexecdir=/usr/lib \
    --disable-obex --disable-cups --disable-mesh --disable-manpages --enable-library \
    --enable-testing --with-systemdsystemunitdir=/usr/lib/systemd/system
  make
}

package() {
  cd "bluez-$pkgver"
  make DESTDIR="$pkgdir" install
  # btvirt wird nicht installiert (noinst); nur fuer Tests, nicht im Suchpfad.
  install -Dm755 emulator/btvirt "$pkgdir/usr/lib/bluetooth/btvirt"
  install -d -m700 "$pkgdir/var/lib/bluetooth"
  [ -x "$pkgdir/usr/lib/bluetooth/bluetoothd" ] && [ -x "$pkgdir/usr/bin/bluetoothctl" ] \
    || { echo "bluez: bluetoothd oder bluetoothctl fehlt" >&2; return 1; }
}
