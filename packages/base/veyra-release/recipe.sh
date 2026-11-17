# Veyra-Systemidentitaet: /etc/os-release und /etc/veyra-release.
pkgname=veyra-release
pkgver=0.5.0
pkgrel=1
pkgdesc="Veyra OS Systemidentitaet (os-release)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS

package() {
  install -d "$pkgdir/etc" "$pkgdir/usr/lib"
  cat > "$pkgdir/usr/lib/os-release" <<OS
NAME="Veyra OS"
PRETTY_NAME="Veyra OS $pkgver"
ID=veyra
VERSION="$pkgver (Core)"
VERSION_ID=$pkgver
HOME_URL="https://github.com/MagieGubi/Veyra-OS"
BUG_REPORT_URL="https://github.com/MagieGubi/Veyra-OS/issues"
OS
  ln -s ../usr/lib/os-release "$pkgdir/etc/os-release"
  echo "Veyra OS $pkgver" > "$pkgdir/etc/veyra-release"
}
