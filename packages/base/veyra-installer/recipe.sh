# Installer fuer Veyra OS (Kommandozeile): veyra-install liste | pruefe ZIEL | installiere ZIEL.
# Logik in veyra_install.py (Partitionen, Kopieren, Einrichten, Pruefen) und veyra_fat.py
# (FAT32 fuer die EFI-Systempartition, das Basissystem hat kein mkfs.fat), Oberflaeche in
# veyra-install. Alle drei liegen neben diesem Rezept; bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/installer/installer-test.sh prueft das).
pkgname=veyra-installer
pkgver=0.1
pkgrel=1
pkgdesc="Installer: Veyra auf einen Datentraeger installieren (GPT, EFI, ext4)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(veyra-install veyra_install.py veyra_fat.py)
sha256sums=(8277de833b80c6b2d3627e9326a34cf6105011e0fe55d40e021b1725d1712360 cc3b1d7c26f82abda117daeed15f2cabcd8fea8da77c6ba8927463bef61d40d2 59416f398e11971468a5e5ea8582dc6f19b0bd4737254ad976406b2518a2e3a2)
depends=(python util-linux e2fsprogs coreutils vpkg veyra-konten)

package() {
  install -Dm755 "$srcdir/veyra-install" "$pkgdir/usr/bin/veyra-install"
  install -Dm644 "$srcdir/veyra_install.py" "$pkgdir/usr/lib/veyra/installer/veyra_install.py"
  install -Dm644 "$srcdir/veyra_fat.py" "$pkgdir/usr/lib/veyra/installer/veyra_fat.py"
}
