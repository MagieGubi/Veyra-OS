# Testpaket fuer den Selbsttest im Entwicklungsabbild: wird im laufenden System mit
# VPKG installiert und wieder entfernt. Das Install-Skript hinterlaesst eine Markierung.
pkgname=vpkg-demo
pkgver=1
pkgrel=1
pkgdesc="Testpaket fuer den VPKG-Selbsttest"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
depends=(bash glibc)

package() {
  install -d "$pkgdir/usr/bin"
  printf '#!/bin/bash\necho "vpkg-demo laeuft"\n' > "$pkgdir/usr/bin/vpkg-demo"
  chmod 755 "$pkgdir/usr/bin/vpkg-demo"
}

post_install() {
  mkdir -p /var/lib/vpkg-demo
  echo "post_install von $pkgname $pkgver-$pkgrel" > /var/lib/vpkg-demo/marker
}
