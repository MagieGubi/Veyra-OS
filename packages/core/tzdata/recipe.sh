pkgname=tzdata
pkgver=2025b
pkgdesc="Zeitzonen-Datenbank"
license=PD
url=https://www.iana.org/time-zones
sources=(https://www.iana.org/time-zones/repository/releases/tzdata2025b.tar.gz)
sha256sums=()
depends=(glibc)

package() {
  z=$pkgdir/usr/share/zoneinfo
  mkdir -p "$z"/{posix,right}
  for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do
    zic -L /dev/null -d "$z" "$tz"
    zic -L /dev/null -d "$z/posix" "$tz"
    zic -L leapseconds -d "$z/right" "$tz"
  done
  cp zone.tab zone1970.tab iso3166.tab "$z"
  zic -d "$z" -p America/New_York
}
