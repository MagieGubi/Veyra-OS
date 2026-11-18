# Metapaket (VPKG 0.6): keine eigenen Dateien, zieht die Pakete der Gruppe @veyra-development nach.
# Gruppe installieren: vpkg install veyra-development (dieses Paket) oder vpkg install @veyra-development.
pkgname=veyra-development
pkgver=0.6
pkgrel=1
pkgdesc="Compiler und Bauwerkzeuge (Metapaket, nur auf Wunsch)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-development)
depends=(gcc binutils make patch pkgconf m4 autoconf automake libtool bison flex gettext gperf perl python meson ninja texinfo file)

package() { :; }
