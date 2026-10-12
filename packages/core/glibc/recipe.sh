pkgname=glibc
pkgver=2.42
pkgdesc="GNU C-Bibliothek"
license=LGPL-2.1-or-later
url=https://www.gnu.org/software/libc/
sources=(https://ftp.gnu.org/gnu/glibc/glibc-2.42.tar.xz
         https://www.linuxfromscratch.org/patches/lfs/12.4/glibc-2.42-fhs-1.patch)
sha256sums=()

build() {
  cd "glibc-$pkgver"
  patch -Np1 -i ../glibc-2.42-fhs-1.patch
  mkdir build && cd build
  echo "rootsbindir=/usr/sbin" > configparms
  ../configure --prefix=/usr --disable-werror --disable-nscd libc_cv_slibdir=/usr/lib \
    --enable-stack-protector=strong --enable-kernel=5.4
  make
}

package() {
  cd "glibc-$pkgver/build"
  mkdir -p "$pkgdir/etc"
  touch "$pkgdir/etc/ld.so.conf"
  sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
  make install_root="$pkgdir" install
  sed '/RTLDLIST=/s@/usr@@g' -i "$pkgdir/usr/bin/ldd"
  cat > "$pkgdir/etc/nsswitch.conf" <<'NSS'
passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files
NSS
  cat > "$pkgdir/etc/ld.so.conf" <<'LDSO'
/usr/local/lib
/opt/lib
include /etc/ld.so.conf.d/*.conf
LDSO
  mkdir -p "$pkgdir/etc/ld.so.conf.d"
  rm -f "$pkgdir/etc/ld.so.cache"
}

# Locales liegen in /usr/lib/locale/locale-archive (wird erzeugt, gehoert keinem Paket).
post_install() {
  mkdir -p /usr/lib/locale
  localedef -i C -f UTF-8 C.UTF-8
  localedef -i en_US -f UTF-8 en_US.UTF-8
  localedef -i de_DE -f UTF-8 de_DE.UTF-8
  localedef -i de_AT -f UTF-8 de_AT.UTF-8
}
