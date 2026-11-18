# Metapaket (VPKG 0.6): keine eigenen Dateien, zieht die Pakete der Gruppe @veyra-security nach.
# Gruppe installieren: vpkg install veyra-security (dieses Paket) oder vpkg install @veyra-security.
pkgname=veyra-security
pkgver=0.6
pkgrel=1
pkgdesc="Firewall und Kernel-Haertung (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-security)
depends=(nftables veyra-firewall veyra-sicherheit shadow)

package() { :; }
