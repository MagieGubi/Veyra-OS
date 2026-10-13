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
sha256sums=(f6f3db8a82950854612b08e4aeae5a56512902b198c7254d22a381f3f1f7d9ff)
depends=(python bash coreutils tar zstd openssl)

package() {
  install -Dm755 "$srcdir/vpkg" "$pkgdir/usr/bin/vpkg"
  install -d "$pkgdir/etc/vpkg/keys" "$pkgdir/var/lib/vpkg/installed"
}
