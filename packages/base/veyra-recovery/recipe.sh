# Metapaket (VPKG 0.6): keine eigenen Dateien, zieht die Pakete der Gruppe @veyra-recovery nach.
# Gruppe installieren: vpkg install veyra-recovery (dieses Paket) oder vpkg install @veyra-recovery.
pkgname=veyra-recovery
pkgver=0.6
pkgrel=1
pkgdesc="Werkzeuge zur Reparatur (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-recovery)
depends=(e2fsprogs util-linux coreutils kbd less vpkg veyra-installer veyra-boot)

package() { :; }
