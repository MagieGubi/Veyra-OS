# VPKG 0.2: Paketverwaltung von Veyra OS (installieren, entfernen, Abhaengigkeiten).
# Das Programm liegt neben diesem Rezept (Datei vpkg); bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/vpkg/run.sh prueft das).
pkgname=vpkg
pkgver=0.2
pkgrel=1
pkgdesc="Paketverwaltung von Veyra OS"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(vpkg)
sha256sums=(d7b486bb4a3cecc8d879d57e2766b22c06b45d892a007cd9aea0747607c1cefc)
depends=(python bash coreutils tar zstd openssl)

package() {
  install -Dm755 "$srcdir/vpkg" "$pkgdir/usr/bin/vpkg"
  install -d "$pkgdir/etc/vpkg/keys" "$pkgdir/var/lib/vpkg/installed"
}
