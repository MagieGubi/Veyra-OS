# Gefuehrter Hardware-Test fuer Veyra 0.7 (nur im Laptop-Testabbild, docs/hardware-test-0.7.md).
# veyra-hardwaretest liegt neben diesem Rezept; bei jeder Aenderung muss sha256sums angepasst
# werden.
pkgname=veyra-hardwaretest
pkgver=0.7
pkgrel=1
pkgdesc="Gefuehrter Test von WLAN, Ton, Bluetooth, Akku, Ruhezustand und Grafik"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(veyra-hardwaretest)
sha256sums=(290361f9057314f4cc422428fa7d6d5f2e72c8d34febaec0b807f5cab6d7bbec)
depends=(python veyra-hwinfo veyra-network veyra-audio veyra-bluetooth veyra-power)

package() {
  install -Dm755 "$srcdir/veyra-hardwaretest" "$pkgdir/usr/bin/veyra-hardwaretest"
}
