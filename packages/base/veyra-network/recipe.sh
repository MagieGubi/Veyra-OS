# Netzwerkwerkzeug und Metapaket der Gruppe @veyra-network (VPKG 0.6): veyra-network zeigt
# Geraete, Adressen, DNS und Zeitabgleich, verbindet WLAN ueber iwd und sammelt eine Diagnose
# ohne Passwoerter. veyra-network liegt neben diesem Rezept; bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/network/network-test.sh prueft das).
pkgname=veyra-network
pkgver=0.7
pkgrel=2
pkgdesc="Netzwerkwerkzeug und Netzwerk per Kabel mit DHCP, DNS und TLS-Wurzelzertifikaten (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-network)
sources=(veyra-network)
sha256sums=(eb7a6c69c37d68ef27b7078e74b8cec699a0919c69966630a1c17792f4dd81f7)
depends=(python systemd iproute2 iwd wireless-regdb veyra-netzwerk veyra-zertifikate)

package() {
  install -Dm755 "$srcdir/veyra-network" "$pkgdir/usr/bin/veyra-network"
}
