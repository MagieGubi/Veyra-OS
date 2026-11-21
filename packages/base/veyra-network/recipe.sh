# Netzwerkwerkzeug und Metapaket der Gruppe @veyra-network (VPKG 0.6): veyra-network zeigt
# Geraete, Adressen, DNS und Zeitabgleich, verbindet WLAN ueber iwd und sammelt eine Diagnose
# ohne Passwoerter. veyra-network liegt neben diesem Rezept; bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/network/network-test.sh prueft das).
pkgname=veyra-network
pkgver=0.7
pkgrel=1
pkgdesc="Netzwerkwerkzeug und Netzwerk per Kabel mit DHCP, DNS und TLS-Wurzelzertifikaten (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-network)
sources=(veyra-network)
sha256sums=(3cbf221dfba11dba64c0999a347fe1796f691fe1c9b4914c5abc8f7529061cce)
depends=(python systemd iproute2 iwd wireless-regdb veyra-netzwerk veyra-zertifikate)

package() {
  install -Dm755 "$srcdir/veyra-network" "$pkgdir/usr/bin/veyra-network"
}
