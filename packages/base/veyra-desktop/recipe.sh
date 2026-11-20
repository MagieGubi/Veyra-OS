# Metapaket der Gruppe @veyra-desktop (Veyra 0.6, Phase 6, experimentell): Desktop-Grundlage
# aus Stufe 5 (Wayland, wlroots, cage, kitty, foot) und der Starter veyra-desktop. veyra-desktop liegt
# neben diesem Rezept; bei jeder Aenderung daran muss sha256sums angepasst werden.
pkgname=veyra-desktop
pkgver=0.6
pkgrel=2
pkgdesc="Desktop-Grundlage: Wayland-Sitzung mit cage und kitty (Metapaket, experimentell)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-desktop)
sources=(veyra-desktop)
sha256sums=(7958c4d9e16a4cb12d6999149f7d49802c0eab035125c0dc55f6faeb33d168a9)
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
