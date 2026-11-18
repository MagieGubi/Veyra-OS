# systemd-boot (Veyra 0.6): Bootloader, Boot-Zaehler (systemd-bless-boot) und EFI-Stubs aus
# derselben systemd-Quelle wie das Paket systemd (LFS baut systemd ohne Bootloader).
# Gebaut wird systemd vollstaendig mit -D bootloader=enabled; ins Paket kommt nur, was das
# installierte systemd noch nicht hat (Bau in chroot, Stufe 4b Teil 4, systemd liegt unter /).
# pyelftools braucht nur der Bau (elf2efi.py), es wird nicht installiert.
pkgname=systemd-boot
pkgver=257.8
pkgdesc="UEFI-Bootloader systemd-boot mit Boot-Zaehler (Rueckfall auf den letzten guten Eintrag)"
license=LGPL-2.1-or-later
url=https://systemd.io
sources=(https://github.com/systemd/systemd/archive/v257.8/systemd-257.8.tar.gz
         https://files.pythonhosted.org/packages/a3/11/767522582afab1b884d277de0e6e011640cb9d7292a38694b4b1a1df1ae8/pyelftools-0.33.tar.gz)
sha256sums=()
depends=(systemd=257.8)
makedepends=(meson ninja gperf jinja2 python)

build() {
  export PYTHONPATH=$srcdir/pyelftools-0.33
  python3 -c 'import elftools' || { echo "pyelftools nicht ladbar" >&2; return 1; }
  cd "systemd-$pkgver"
  sed -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' -i rules.d/50-udev-default.rules.in
  mkdir build && cd build
  # Dieselben Optionen wie packages/core/systemd, dazu der Bootloader. Die SBAT-Angaben
  # stehen fest drin: im chroot gibt es noch kein /etc/os-release (kommt mit veyra-release).
  meson setup .. --prefix=/usr --buildtype=release \
    -D default-dnssec=no -D firstboot=false -D install-tests=false -D ldconfig=false \
    -D rpmmacrosdir=no -D homed=disabled -D userdb=false -D man=disabled -D mode=release \
    -D pam=disabled -D dev-kvm-mode=0660 -D nobody-group=nogroup \
    -D sysupdate=disabled -D ukify=disabled -D docdir="/usr/share/doc/systemd-$pkgver" \
    -D bootloader=enabled \
    -D sbat-distro=veyra -D sbat-distro-summary="Veyra OS" -D sbat-distro-pkgname=systemd-boot \
    -D sbat-distro-version="$pkgver" -D sbat-distro-url=https://github.com/MagieGubi/Veyra-OS
  ninja
}

package() {
  cd "systemd-$pkgver/build"
  local stage=$srcdir/stage p
  DESTDIR="$stage" ninja install
  (cd "$stage" && find . -mindepth 1 \( -type f -o -type l \) | LC_ALL=C sort) | while IFS= read -r p; do
    p=${p#./}
    [ -e "/$p" ] || [ -L "/$p" ] && continue
    install -d "$pkgdir/$(dirname "$p")"
    cp -a "$stage/$p" "$pkgdir/$p"
  done
  for p in usr/lib/systemd/boot/efi/systemd-bootx64.efi usr/lib/systemd/systemd-bless-boot; do
    [ -e "$pkgdir/$p" ] || { echo "erwartet, aber nicht gebaut: /$p" >&2; return 1; }
  done
}

post_install() {
  # Ein Start gilt erst als gut (Boot-Zaehler), wenn bis dahin keine Unit fehlgeschlagen ist.
  systemctl enable systemd-boot-check-no-failures.service
}
