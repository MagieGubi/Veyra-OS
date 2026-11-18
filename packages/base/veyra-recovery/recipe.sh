# Rettungswerkzeug und Metapaket der Gruppe @veyra-recovery (VPKG 0.6): veyra-recovery
# findet installierte Systeme, prueft und repariert sie von der Live-ISO aus. veyra-recovery
# liegt neben diesem Rezept; bei jeder Aenderung daran muss sha256sums angepasst werden
# (tests/recovery/recovery-test.sh prueft das).
pkgname=veyra-recovery
pkgver=0.6.1
pkgrel=1
pkgdesc="Rettungswerkzeug: installiertes Veyra pruefen und reparieren (und Metapaket der Gruppe)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-recovery)
sources=(veyra-recovery)
sha256sums=(9b79fa94c5dd0b37e2223a4fbcc809929cfa3ec21714d1b1a8153eed8d048b11)
depends=(python systemd e2fsprogs util-linux coreutils kbd less vpkg veyra-installer veyra-konten veyra-boot)

package() {
  install -Dm755 "$srcdir/veyra-recovery" "$pkgdir/usr/bin/veyra-recovery"
}
