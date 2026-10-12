pkgname=systemd
pkgver=257.8
pkgdesc="Init-System und Dienstverwaltung"
license=LGPL-2.1-or-later
url=https://systemd.io
sources=(https://github.com/systemd/systemd/archive/v257.8/systemd-257.8.tar.gz)
sha256sums=()
depends=(glibc acl libcap libxcrypt kmod util-linux xz zstd lz4 openssl)
makedepends=(meson ninja gperf jinja2)

build() {
  cd "systemd-$pkgver"
  sed -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' -i rules.d/50-udev-default.rules.in
  mkdir build && cd build
  meson setup .. --prefix=/usr --buildtype=release \
    -D default-dnssec=no -D firstboot=false -D install-tests=false -D ldconfig=false \
    -D rpmmacrosdir=no -D homed=disabled -D userdb=false -D man=disabled -D mode=release \
    -D pamconf=false -D pam=disabled -D dev-kvm-mode=0660 -D nobody-group=nogroup \
    -D sysupdate=disabled -D ukify=disabled -D docdir="/usr/share/doc/systemd-$pkgver"
  ninja
}

package() {
  cd "systemd-$pkgver/build"
  DESTDIR="$pkgdir" ninja install
}

post_install() {
  systemd-sysusers
  systemd-machine-id-setup
  systemctl preset-all
}
