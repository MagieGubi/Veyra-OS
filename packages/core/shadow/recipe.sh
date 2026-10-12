pkgname=shadow
pkgver=4.18.0
pkgdesc="Nutzer- und Passwortverwaltung"
license=BSD-3-Clause
url=https://github.com/shadow-maint/shadow
sources=(https://github.com/shadow-maint/shadow/releases/download/4.18.0/shadow-4.18.0.tar.xz)
sha256sums=()
depends=(glibc acl attr libxcrypt)

build() {
  cd "shadow-$pkgver"
  # groups kommt aus coreutils
  sed -i 's/groups$(EXEEXT) //' src/Makefile.in
  find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
  find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
  find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;
  sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
      -e 's:/var/spool/mail:/var/mail:' \
      -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' \
      -i etc/login.defs
  touch /usr/bin/passwd
  ./configure --sysconfdir=/etc --disable-static --with-{b,yes}crypt --without-libbsd \
    --with-group-name-max-length=32
  make
}

package() {
  cd "shadow-$pkgver"
  make exec_prefix=/usr DESTDIR="$pkgdir" install
  mkdir -p "$pkgdir/etc/default"
}

post_install() {
  pwconv
  grpconv
  useradd -D --gid 999
  sed -i '/MAIL/s/yes/no/' /etc/default/useradd
}
