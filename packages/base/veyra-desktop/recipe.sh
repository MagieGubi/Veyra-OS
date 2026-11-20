# Metapaket der Gruppe @veyra-desktop (Veyra 0.6, Phase 6, experimentell): Desktop-Grundlage
# aus Stufe 5 (Wayland, wlroots, cage, foot) und der Starter veyra-desktop. veyra-desktop liegt
# neben diesem Rezept; bei jeder Aenderung daran muss sha256sums angepasst werden.
pkgname=veyra-desktop
pkgver=0.6
pkgrel=1
pkgdesc="Desktop-Grundlage: Wayland-Sitzung mit cage und Terminal (Metapaket, experimentell)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-desktop)
sources=(veyra-desktop)
sha256sums=(a598908de464d543c82f5ffc18df1493f144f1ff61568c35b30c0b9eb97bedcb)
depends=(cage foot seatd dejavu-fonts xkeyboard-config systemd)

package() {
  install -Dm755 "$srcdir/veyra-desktop" "$pkgdir/usr/bin/veyra-desktop"
}

post_install() {
  systemctl enable seatd.service >/dev/null 2>&1 || true
}

pre_remove() {
  systemctl disable seatd.service >/dev/null 2>&1 || true
}
