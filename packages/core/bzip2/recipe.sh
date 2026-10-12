pkgname=bzip2
pkgver=1.0.8
pkgdesc="Blocksortierender Kompressor"
license=bzip2-1.0.6
url=https://sourceware.org/bzip2/
sources=(https://www.sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
         https://www.linuxfromscratch.org/patches/lfs/12.4/bzip2-1.0.8-install_docs-1.patch)
sha256sums=()
depends=(glibc)

build() {
  cd "bzip2-$pkgver"
  patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
  sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
  sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
  make -f Makefile-libbz2_so
  make clean
  make
}

package() {
  cd "bzip2-$pkgver"
  make PREFIX="$pkgdir/usr" install
  cp -a libbz2.so.* "$pkgdir/usr/lib"
  ln -s libbz2.so.1.0.8 "$pkgdir/usr/lib/libbz2.so"
  cp bzip2-shared "$pkgdir/usr/bin/bzip2"
  for i in bzcat bunzip2; do ln -sf bzip2 "$pkgdir/usr/bin/$i"; done
  rm -f "$pkgdir/usr/lib/libbz2.a"
}
