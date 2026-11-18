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
sha256sums=(e85ccbe04198a18de9e8622b518f36212b3d844d0b08d38f71789e47d4e685da)
depends=(python)

package() {
  install -Dm755 "$srcdir/veyra-hwinfo" "$pkgdir/usr/bin/veyra-hwinfo"
}
