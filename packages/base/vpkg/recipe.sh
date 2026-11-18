# VPKG 0.6: Paketverwaltung von Veyra OS (Quellen mit Spiegeln, Cache, Gruppen).
# Das Programm liegt neben diesem Rezept (Datei vpkg); bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/vpkg/run.sh prueft das).
pkgname=vpkg
pkgver=0.6
pkgrel=1
pkgdesc="Paketverwaltung von Veyra OS"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(vpkg)
sha256sums=(d406bc5017a440a7b87af2305cb52caa88170eb9ff056e871bf85221e4be578e)
depends=(python bash coreutils tar zstd openssl)

package() {
  install -Dm755 "$srcdir/vpkg" "$pkgdir/usr/bin/vpkg"
  install -d "$pkgdir/etc/vpkg/keys" "$pkgdir/etc/vpkg/repos.d" "$pkgdir/var/lib/vpkg/installed" \
    "$pkgdir/var/cache/vpkg"
}
