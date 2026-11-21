# Hardware-Erkennung (Veyra 0.7): veyra-hwinfo liest /proc und /sys und aktiviert nichts.
# veyra-hwinfo und firmware-katalog.json (welche Hardware welches Firmware-Paket braucht)
# liegen neben diesem Rezept; bei jeder Aenderung muss sha256sums angepasst werden
# (tests/hwinfo/hwinfo-test.sh prueft das).
pkgname=veyra-hwinfo
pkgver=0.2
pkgrel=1
pkgdesc="Hardware erkennen und beschreiben (nur lesen, Text und JSON)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-base)
sources=(veyra-hwinfo firmware-katalog.json)
sha256sums=(cfffd7aa85369045eeb90bfc95bac2a12b4b8a0b70df7552f0b0d78de402ce49 3996428bf42851f603125fd83074da0b45105c4838dfe9b189dfb3197e2fe258)
depends=(python)

package() {
  install -Dm755 "$srcdir/veyra-hwinfo" "$pkgdir/usr/bin/veyra-hwinfo"
  install -Dm644 "$srcdir/firmware-katalog.json" "$pkgdir/usr/share/veyra-hwinfo/firmware-katalog.json"
}
