# Metapaket (Veyra 0.7): alle Firmware-Pakete von Veyra. Einzeln reicht meist:
# "veyra-hwinfo firmware" zeigt, welche die Hardware braucht.
pkgname=veyra-firmware
pkgver=0.7
pkgrel=2
pkgdesc="Alle Firmware-Pakete (Intel-WLAN, -Grafik, -Bluetooth, AMD-Grafik) (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-firmware)
depends=(veyra-firmware-intel-wlan veyra-firmware-intel-grafik veyra-firmware-intel-bluetooth
         veyra-firmware-amd-grafik)

package() { :; }
