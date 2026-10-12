pkgname=binutils
pkgver=2.45
pkgdesc="Assembler, Linker und Werkzeuge fuer Objektdateien"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/binutils/
sources=(https://ftp.gnu.org/gnu/binutils/binutils-2.45.tar.xz)
sha256sums=()
depends=(glibc zlib zstd)

build() {
  cd "binutils-$pkgver"
  mkdir build && cd build
  ../configure --prefix=/usr --sysconfdir=/etc --enable-ld=default --enable-plugins --enable-shared \
    --disable-werror --enable-64-bit-bfd --enable-new-dtags --with-system-zlib \
    --enable-default-hash-style=gnu
  make tooldir=/usr
}

package() {
  cd "binutils-$pkgver/build"
  make tooldir=/usr DESTDIR="$pkgdir" install
  rm -rf "$pkgdir"/usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a "$pkgdir/usr/share/doc/gprofng"
}
