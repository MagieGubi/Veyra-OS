# VPKG 0.4: Paketverwaltung von Veyra OS (installieren, entfernen, Abhaengigkeiten).
# Das Programm liegt neben diesem Rezept (Datei vpkg); bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/vpkg/run.sh prueft das).
pkgname=vpkg
pkgver=0.4.1
pkgrel=1
pkgdesc="Paketverwaltung von Veyra OS"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(vpkg)
sha256sums=(bdd29ad17a5a1b3a54e9da24a955473b92db8054bbed5782e6255c0d9f808451)
depends=(python bash coreutils tar zstd openssl)

package() {
  install -Dm755 "$srcdir/vpkg" "$pkgdir/usr/bin/vpkg"
  install -d "$pkgdir/etc/vpkg/keys" "$pkgdir/var/lib/vpkg/installed"
}
