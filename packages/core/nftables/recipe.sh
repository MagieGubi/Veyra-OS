pkgname=nftables
pkgver=1.1.3
pkgdesc="nft: Firewall-Regeln fuer nf_tables"
license=GPL-2.0-only
url=https://www.netfilter.org/projects/nftables/
sources=(https://www.netfilter.org/pub/nftables/nftables-1.1.3.tar.xz)
sha256sums=()
depends=(glibc gmp libmnl libnftnl)

build() {
  cd "nftables-$pkgver"
  # Minimal: keine interaktive Kommandozeile, kein JSON, keine Python-Bindung, keine
  # Handbuchseiten (braucht asciidoc). Regeln kommen aus Dateien (veyra-firewall).
  ./configure --prefix=/usr --sysconfdir=/etc --disable-static --disable-debug \
    --with-cli=no --without-json --disable-python --disable-man-doc --with-mini-gmp=no
  make
}

package() {
  cd "nftables-$pkgver"
  make DESTDIR="$pkgdir" install
  # Beispielregeln des Upstream-Projekts nicht mitliefern: Veyra bringt eigene (veyra-firewall)
  rm -rf "$pkgdir/usr/share/nftables" "$pkgdir/usr/share/doc"
}
