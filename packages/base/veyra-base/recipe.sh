# Metapaket (VPKG 0.6): keine eigenen Dateien, zieht die Pakete der Gruppe @veyra-base nach.
# Gruppe installieren: vpkg install veyra-base (dieses Paket) oder vpkg install @veyra-base.
pkgname=veyra-base
pkgver=0.6
pkgrel=1
pkgdesc="Grundsystem von Veyra OS (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-base)
depends=(glibc bash coreutils util-linux systemd dbus shadow kmod kbd iproute2 procps-ng psmisc findutils grep sed gawk diffutils less tar gzip bzip2 xz zstd e2fsprogs vpkg veyra-release veyra-konten)

package() { :; }
