pkgname=dejavu-fonts
pkgver=2.37
pkgdesc="Schriften DejaVu Sans, Serif und Sans Mono"
license=Bitstream-Vera
url=https://dejavu-fonts.github.io/
sources=(https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2)
sha256sums=()
depends=(fontconfig)

build() {
  :
}

package() {
  cd "dejavu-fonts-ttf-$pkgver"
  install -d "$pkgdir/usr/share/fonts/dejavu" "$pkgdir/usr/share/fontconfig/conf.avail" \
    "$pkgdir/etc/fonts/conf.d" "$pkgdir/usr/share/licenses/dejavu-fonts"
  install -m644 ttf/*.ttf "$pkgdir/usr/share/fonts/dejavu/"
  install -m644 fontconfig/*.conf "$pkgdir/usr/share/fontconfig/conf.avail/"
  local f
  for f in fontconfig/*.conf; do
    ln -s "/usr/share/fontconfig/conf.avail/${f##*/}" "$pkgdir/etc/fonts/conf.d/${f##*/}"
  done
  install -m644 LICENSE "$pkgdir/usr/share/licenses/dejavu-fonts/LICENSE"
}

post_install() {
  fc-cache -s >/dev/null 2>&1 || true
}
