pkgname=coreutils
pkgver=9.7
pkgdesc="GNU-Grundwerkzeuge (ls, cp, mv ...)"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/coreutils/
sources=(https://ftp.gnu.org/gnu/coreutils/coreutils-9.7.tar.xz
         https://www.linuxfromscratch.org/patches/lfs/12.4/coreutils-9.7-upstream_fix-1.patch
         https://www.linuxfromscratch.org/patches/lfs/12.4/coreutils-9.7-i18n-1.patch)
sha256sums=()
depends=(glibc acl attr libcap openssl)

build() {
  cd "coreutils-$pkgver"
  patch -Np1 -i ../coreutils-9.7-upstream_fix-1.patch
  patch -Np1 -i ../coreutils-9.7-i18n-1.patch
  autoreconf -fv
  automake -af
  FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --enable-no-install-program=kill,uptime
  make
}

package() {
  cd "coreutils-$pkgver"
  make DESTDIR="$pkgdir" install
  mkdir -p "$pkgdir/usr/sbin" "$pkgdir/usr/share/man/man8"
  mv "$pkgdir/usr/bin/chroot" "$pkgdir/usr/sbin"
  mv "$pkgdir/usr/share/man/man1/chroot.1" "$pkgdir/usr/share/man/man8/chroot.8"
  sed -i 's/"1"/"8"/' "$pkgdir/usr/share/man/man8/chroot.8"
}
