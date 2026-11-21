# Metapaket (Veyra 0.7): was ein Laptop braucht. Netzwerk mit WLAN, Ton, Bluetooth,
# Energieverwaltung und Firmware. Gruppe: vpkg install @veyra-laptop.
pkgname=veyra-laptop
pkgver=0.7
pkgrel=1
pkgdesc="Laptop: WLAN, Ton, Bluetooth, Energie, Firmware (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-laptop)
depends=(veyra-network veyra-audio veyra-bluetooth veyra-power veyra-firmware)

package() { :; }
