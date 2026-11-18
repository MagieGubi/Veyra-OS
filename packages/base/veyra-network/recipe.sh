# Netzwerkwerkzeug und Metapaket der Gruppe @veyra-network (VPKG 0.6): veyra-network zeigt
# Geraete, Adressen, DNS und Zeitabgleich, verbindet WLAN ueber iwd und sammelt eine Diagnose
# ohne Passwoerter. veyra-network liegt neben diesem Rezept; bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/network/network-test.sh prueft das).
pkgname=veyra-network
pkgver=0.6.1
pkgrel=1
pkgdesc="Netzwerkwerkzeug und Netzwerk per Kabel mit DHCP, DNS und TLS-Wurzelzertifikaten (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-network)
sources=(veyra-network)
sha256sums=(7970f56e9fb303de49f2d3a28c54ea1d635c38c1b1d5ed5d7a8ae90678d859e5)
depends=(python systemd iproute2 iwd wireless-regdb veyra-netzwerk veyra-zertifikate)

package() {
  install -Dm755 "$srcdir/veyra-network" "$pkgdir/usr/bin/veyra-network"
}
