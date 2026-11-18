pkgname=wireless-regdb
pkgver=2026.09.03
pkgdesc="Erlaubte WLAN-Frequenzen und Sendeleistungen je Land (regulatory.db, signiert)"
license=ISC
url=https://wireless.wiki.kernel.org/en/developers/regulatory/wireless-regdb
sources=(https://cdn.kernel.org/pub/software/network/wireless-regdb/wireless-regdb-2026.09.03.tar.xz)
sha256sums=()

package() {
  cd "wireless-regdb-$pkgver"
  # Der Kernel prueft regulatory.db.p7s mit dem eingebauten Schluessel des Projekts.
  install -Dm644 regulatory.db "$pkgdir/usr/lib/firmware/regulatory.db"
  install -Dm644 regulatory.db.p7s "$pkgdir/usr/lib/firmware/regulatory.db.p7s"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/wireless-regdb/LICENSE"
}
