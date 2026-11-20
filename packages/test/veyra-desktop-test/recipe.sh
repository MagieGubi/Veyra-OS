# Nur fuer den Desktop-Test im CI (image/desktop-test.py): startet beim Booten als Benutzer
# desktest cage mit kitty. Nie in ein Abbild fuer Menschen.
pkgname=veyra-desktop-test
pkgver=0.2
pkgrel=1
pkgdesc="Desktop-Test fuer das CI: cage und kitty beim Start (nicht fuer echte Systeme)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(bild.sh veyra-desktop-test.service desktest.conf)
sha256sums=(2f2bc1b132f5046da4395f72c4f86e3b578d10f4594116ce916a9bc8f9cc862e 4333d078ec29d1d31da533889e7994fde7fa21c561ff7b53b32566f911c37486 e54e42aab667aae3c2cf0013c2e073483cc09f2ee18aa7be5c23005b0a9da5c1)
depends=(veyra-desktop kitty veyra-hwinfo)

package() {
  install -Dm755 "$srcdir/bild.sh" "$pkgdir/usr/lib/veyra/desktop-test/bild.sh"
  install -Dm644 "$srcdir/veyra-desktop-test.service" "$pkgdir/usr/lib/systemd/system/veyra-desktop-test.service"
  install -Dm644 "$srcdir/desktest.conf" "$pkgdir/usr/lib/sysusers.d/veyra-desktop-test.conf"
}

post_install() {
  systemd-sysusers /usr/lib/sysusers.d/veyra-desktop-test.conf
  systemctl enable veyra-desktop-test.service >/dev/null 2>&1
}
