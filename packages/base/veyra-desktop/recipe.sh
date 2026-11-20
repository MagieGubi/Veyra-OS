# Metapaket der Gruppe @veyra-desktop (Veyra 0.6, Phase 6, experimentell): Desktop-Grundlage
# aus Stufe 5 (Wayland, wlroots, cage, kitty, foot) und der Starter veyra-desktop. veyra-desktop liegt
# neben diesem Rezept; bei jeder Aenderung daran muss sha256sums angepasst werden.
pkgname=veyra-desktop
pkgver=0.6
pkgrel=3
pkgdesc="Desktop-Grundlage: Wayland-Sitzung mit cage und kitty (Metapaket, experimentell)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-desktop)
sources=(veyra-desktop)
sha256sums=(199c9113da1991822b129fdd72ec23d5ef69915ab91638e412081accf5a02f2f)
depends=(cage kitty foot seatd dejavu-fonts xkeyboard-config systemd)

package() {
  install -Dm755 "$srcdir/veyra-desktop" "$pkgdir/usr/bin/veyra-desktop"
}

post_install() {
  systemctl enable seatd.service >/dev/null 2>&1 || true
}

pre_remove() {
  systemctl disable seatd.service >/dev/null 2>&1 || true
}
