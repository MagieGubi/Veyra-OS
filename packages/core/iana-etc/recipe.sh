pkgname=iana-etc
pkgver=20250807
pkgdesc="Netzwerkdienste und -protokolle (/etc/services, /etc/protocols)"
license=MIT
url=https://github.com/Mic92/iana-etc
sources=(https://github.com/Mic92/iana-etc/releases/download/20250807/iana-etc-20250807.tar.gz)
sha256sums=()

package() {
  cd "iana-etc-$pkgver"
  install -Dm644 -t "$pkgdir/etc" services protocols
}
