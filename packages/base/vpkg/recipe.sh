# VPKG 0.1: Paketverwaltung von Veyra OS (installieren, entfernen, Abhaengigkeiten).
# Das Programm liegt neben diesem Rezept (Datei vpkg); bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/vpkg/run.sh prueft das).
pkgname=vpkg
pkgver=0.1
pkgrel=1
pkgdesc="Paketverwaltung von Veyra OS"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(vpkg)
sha256sums=(227fa4cc75b54da1590d26031cee2331f68d0f4089e45dd74292f1c618e2c856)
depends=(python bash coreutils tar zstd openssl)

package() {
  install -Dm755 "$srcdir/vpkg" "$pkgdir/usr/bin/vpkg"
  install -d "$pkgdir/etc/vpkg/keys" "$pkgdir/var/lib/vpkg/installed"
}
