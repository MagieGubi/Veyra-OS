pkgname=e2fsprogs
pkgver=1.47.3
pkgdesc="Werkzeuge fuer ext2/3/4"
license=GPL-2.0-or-later
url=https://e2fsprogs.sourceforge.net
sources=(https://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.gz)
sha256sums=()
depends=(glibc util-linux)

build() {
  cd "e2fsprogs-$pkgver"
  mkdir build && cd build
  ../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs --disable-libblkid \
    --disable-libuuid --disable-uuidd --disable-fsck
  make
}

package() {
  cd "e2fsprogs-$pkgver/build"
  make DESTDIR="$pkgdir" install
  rm -f "$pkgdir"/usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
}
