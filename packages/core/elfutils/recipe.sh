pkgname=elfutils
pkgver=0.193
pkgdesc="libelf (Bibliothek fuer ELF-Dateien)"
license="LGPL-3.0-or-later OR GPL-2.0-or-later"
url=https://sourceware.org/elfutils/
sources=(https://sourceware.org/ftp/elfutils/0.193/elfutils-0.193.tar.bz2)
sha256sums=()
depends=(glibc zlib bzip2 xz zstd)
provides=(libelf)

build() {
  cd "elfutils-$pkgver"
  ./configure --prefix=/usr --disable-debuginfod --enable-libdebuginfod=dummy
  make
}

package() {
  cd "elfutils-$pkgver"
  make -C libelf DESTDIR="$pkgdir" install
  install -Dm644 config/libelf.pc "$pkgdir/usr/lib/pkgconfig/libelf.pc"
  rm -f "$pkgdir/usr/lib/libelf.a"
}
