# Installer fuer Veyra OS (Kommandozeile): veyra-install liste | pruefe ZIEL | installiere ZIEL.
# Logik in veyra_install.py (Partitionen, Kopieren, Einrichten, Pruefen) und veyra_fat.py
# (FAT32 fuer die EFI-Systempartition, das Basissystem hat kein mkfs.fat), Oberflaeche in
# veyra-install. veyra-rootpruefung warnt beim Start, wenn zwei Partitionen veyra-root
# heissen (Bootweg A, docs/PLAN_0.5.md). Alle vier liegen neben diesem Rezept; bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/installer/installer-test.sh prueft das).
pkgname=veyra-installer
pkgver=0.4
pkgrel=2
pkgdesc="Installer: Veyra auf einen Datentraeger installieren (GPT, EFI, ext4)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(veyra-install veyra_install.py veyra_fat.py veyra-rootpruefung)
sha256sums=(d360e0c4ed02f60c786dd8ddeddc76a7dcc6309cfa34da562d73ca2af75470ae 9657770971b2ceeff1bdbaddb2ad3d60112b18c333c7b9c1331d0a643d383e24 69a77d1a3f675bd2562febbc21cd746097eae5d192babd50fca222f81ed444bf a47fb12e8592faf1650f20f4dfdae687a52807f829fb6ea9e078ae8d9ca6eaaf)
depends=(python util-linux e2fsprogs coreutils vpkg veyra-konten)

package() {
  install -Dm755 "$srcdir/veyra-install" "$pkgdir/usr/bin/veyra-install"
  install -Dm644 "$srcdir/veyra_install.py" "$pkgdir/usr/lib/veyra/installer/veyra_install.py"
  install -Dm644 "$srcdir/veyra_fat.py" "$pkgdir/usr/lib/veyra/installer/veyra_fat.py"
  install -Dm755 "$srcdir/veyra-rootpruefung" "$pkgdir/usr/lib/veyra/veyra-rootpruefung"
  install -d "$pkgdir/usr/lib/systemd/system/multi-user.target.wants"
  cat > "$pkgdir/usr/lib/systemd/system/veyra-rootpruefung.service" <<'UNIT'
[Unit]
Description=Veyra: warnen, wenn mehrere Partitionen veyra-root heissen
After=local-fs.target systemd-udev-settle.service
Before=getty@tty1.service serial-getty@ttyS0.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/lib/veyra/veyra-rootpruefung
StandardError=journal+console
UNIT
  ln -s ../veyra-rootpruefung.service \
    "$pkgdir/usr/lib/systemd/system/multi-user.target.wants/veyra-rootpruefung.service"
}
