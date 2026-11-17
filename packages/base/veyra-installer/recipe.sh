# Installer fuer Veyra OS (Kommandozeile): veyra-install liste | pruefe ZIEL | installiere ZIEL.
# Logik in veyra_install.py (Partitionen, Kopieren, Einrichten, Pruefen) und veyra_fat.py
# (FAT32 fuer die EFI-Systempartition, das Basissystem hat kein mkfs.fat), Oberflaeche in
# veyra-install. veyra-rootpruefung warnt beim Start, wenn zwei Partitionen veyra-root
# heissen (Bootweg A, docs/PLAN_0.5.md). Alle vier liegen neben diesem Rezept; bei jeder Aenderung daran muss
# sha256sums angepasst werden (tests/installer/installer-test.sh prueft das).
pkgname=veyra-installer
pkgver=0.3
pkgrel=1
pkgdesc="Installer: Veyra auf einen Datentraeger installieren (GPT, EFI, ext4)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(veyra-install veyra_install.py veyra_fat.py veyra-rootpruefung)
sha256sums=(9e3f4ab38dbdc304d7a5afa1bd260d82fd1aef25724c970811652f58f02c9444 4bdf6ef076a8eea223028ecb0d819e727d705a04bf698dab22a34e0fee762731 59416f398e11971468a5e5ea8582dc6f19b0bd4737254ad976406b2518a2e3a2 a47fb12e8592faf1650f20f4dfdae687a52807f829fb6ea9e078ae8d9ca6eaaf)
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
