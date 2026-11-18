# Hardware-Erkennung (Veyra 0.6): veyra-hwinfo liest /proc und /sys und aktiviert nichts.
# veyra-hwinfo liegt neben diesem Rezept; bei jeder Aenderung daran muss sha256sums angepasst
# werden (tests/hwinfo/hwinfo-test.sh prueft das).
pkgname=veyra-hwinfo
pkgver=0.1
pkgrel=1
pkgdesc="Hardware erkennen und beschreiben (nur lesen, Text und JSON)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-base)
sources=(veyra-hwinfo)
sha256sums=(7649ea31e66797e2aa45e76501d03c6c4624dda4417896656826ed8899495a85)
depends=(python)

package() {
  install -Dm755 "$srcdir/veyra-hwinfo" "$pkgdir/usr/bin/veyra-hwinfo"
}
