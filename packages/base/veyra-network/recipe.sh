# Metapaket (VPKG 0.6): keine eigenen Dateien, zieht die Pakete der Gruppe @veyra-network nach.
# Gruppe installieren: vpkg install veyra-network (dieses Paket) oder vpkg install @veyra-network.
pkgname=veyra-network
pkgver=0.6
pkgrel=1
pkgdesc="Netzwerk per Kabel mit DHCP, DNS und TLS-Wurzelzertifikaten (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-network)
depends=(systemd iproute2 veyra-netzwerk veyra-zertifikate)

package() { :; }
