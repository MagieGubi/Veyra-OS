pkgname=hwdata
pkgver=0.413
pkgdesc="Hardware-Kennungen (PNP-IDs der Bildschirmhersteller fuer wlroots)"
license=GPL-2.0-or-later
url=https://github.com/vcrhonek/hwdata
sources=(https://github.com/vcrhonek/hwdata/archive/refs/tags/v0.413.tar.gz)
sha256sums=()
depends=()

build() {
  cd "hwdata-$pkgver"
  ./configure --prefix=/usr --disable-blacklist
}

package() {
  cd "hwdata-$pkgver"
  make DESTDIR="$pkgdir" install
  [ -f "$pkgdir/usr/share/hwdata/pnp.ids" ] || { echo "pnp.ids fehlt" >&2; return 1; }
}
