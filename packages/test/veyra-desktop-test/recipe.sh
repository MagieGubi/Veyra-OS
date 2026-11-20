# Nur fuer den Desktop-Test im CI (image/desktop-test.py): startet beim Booten als Benutzer
# desktest cage mit foot. Nie in ein Abbild fuer Menschen.
pkgname=veyra-desktop-test
pkgver=0.1
pkgrel=1
pkgdesc="Desktop-Test fuer das CI: cage und foot beim Start (nicht fuer echte Systeme)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(bild.sh veyra-desktop-test.service desktest.conf)
sha256sums=(899acc6024bde7f584022f30edbfb00465348e65aa93fbef9ff8101d707b3652 b611308e180f6bd1ead6bac0208ac4fbdbaadc3420ba6c74c3aac94566f7704e e54e42aab667aae3c2cf0013c2e073483cc09f2ee18aa7be5c23005b0a9da5c1)
depends=(veyra-desktop veyra-hwinfo)

package() {
  install -Dm755 "$srcdir/bild.sh" "$pkgdir/usr/lib/veyra/desktop-test/bild.sh"
  install -Dm644 "$srcdir/veyra-desktop-test.service" "$pkgdir/usr/lib/systemd/system/veyra-desktop-test.service"
  install -Dm644 "$srcdir/desktest.conf" "$pkgdir/usr/lib/sysusers.d/veyra-desktop-test.conf"
}

post_install() {
  systemd-sysusers /usr/lib/sysusers.d/veyra-desktop-test.conf
  systemctl enable veyra-desktop-test.service >/dev/null 2>&1
}
