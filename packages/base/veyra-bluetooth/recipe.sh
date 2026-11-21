# Bluetooth fuer Veyra (0.7) und Metapaket der Gruppe @veyra-bluetooth: BlueZ (bluetoothd,
# bluetoothctl), Zugriffsregel fuer die Gruppe bluetooth und den Tondienst, Werkzeug
# veyra-bluetooth. Bluetooth-Ton kommt ueber PipeWire (veyra-audio). Die Dateien liegen neben
# diesem Rezept; bei jeder Aenderung muss sha256sums angepasst werden
# (tests/bluetooth/bluetooth-test.sh prueft das).
pkgname=veyra-bluetooth
pkgver=0.7
pkgrel=1
pkgdesc="Bluetooth: BlueZ und veyra-bluetooth (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-bluetooth)
sources=(veyra-bluetooth veyra-bluetooth-dbus.conf bluetooth-sysusers.conf)
sha256sums=(0f5bbe46226314a76f5281c24de8eb8d5a6134e535757912eb2b9230d006820f 18616a92d50d9d1c8c167abcbca4d83566ebb4569d6bbf71432a563829814ed2 4a692581cee42b77d201fd9e5777d5ca88f5dbd69143e2a5ea89480ee69afabb)
depends=(python systemd dbus bluez)

package() {
  install -Dm755 "$srcdir/veyra-bluetooth" "$pkgdir/usr/bin/veyra-bluetooth"
  install -Dm644 "$srcdir/veyra-bluetooth-dbus.conf" "$pkgdir/usr/share/dbus-1/system.d/veyra-bluetooth.conf"
  install -Dm644 "$srcdir/bluetooth-sysusers.conf" "$pkgdir/usr/lib/sysusers.d/veyra-bluetooth.conf"
}

post_install() {
  systemd-sysusers /usr/lib/sysusers.d/veyra-bluetooth.conf
  systemctl enable bluetooth.service >/dev/null 2>&1 || true
}

pre_remove() {
  systemctl disable bluetooth.service >/dev/null 2>&1 || true
}
