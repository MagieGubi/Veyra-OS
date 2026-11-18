# Veyra 0.6: Kernel-Updates mit Rueckfall ueber den Boot-Zaehler von systemd-boot.
# veyra-kernel-update liegt neben diesem Rezept; bei jeder Aenderung daran muss sha256sums
# angepasst werden (tests/boot/kernel-update-test.sh prueft das).
pkgname=veyra-boot
pkgver=0.1
pkgrel=1
pkgdesc="Kernel-Updates mit Rueckfall auf den letzten guten Kernel (systemd-boot)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-recovery)
sources=(veyra-kernel-update)
sha256sums=(029bc1c30ede0e54cd9c1c5b5601dd07025809cfa2b2186f659f14155f705277)
depends=(python systemd-boot)

package() {
  install -Dm755 "$srcdir/veyra-kernel-update" "$pkgdir/usr/bin/veyra-kernel-update"
}
