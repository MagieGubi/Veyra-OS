# VPKG 0.6: Paketverwaltung von Veyra OS (Quellen mit Spiegeln, Cache, Gruppen).
# Das Programm liegt neben diesem Rezept (Datei vpkg); bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/vpkg/run.sh prueft das).
pkgname=vpkg
pkgver=0.6
pkgrel=2
pkgdesc="Paketverwaltung von Veyra OS"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(vpkg)
sha256sums=(97125b79760abd24594de97da5ec3f21cfdfac88045dbc094365fe4914b0733f)
depends=(python bash coreutils tar zstd openssl)

package() {
  install -Dm755 "$srcdir/vpkg" "$pkgdir/usr/bin/vpkg"
  install -d "$pkgdir/etc/vpkg/keys" "$pkgdir/etc/vpkg/repos.d" "$pkgdir/var/lib/vpkg/installed" \
    "$pkgdir/var/cache/vpkg"
}
