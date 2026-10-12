pkgname=python
pkgver=3.13.7
pkgdesc="Python 3"
license=PSF-2.0
url=https://www.python.org
sources=(https://www.python.org/ftp/python/3.13.7/Python-3.13.7.tar.xz)
sha256sums=()
depends=(glibc bzip2 expat gdbm libffi libxcrypt ncurses openssl xz zlib)

build() {
  cd "Python-$pkgver"
  # Ohne --enable-optimizations: PGO macht den Build langsam und nicht reproduzierbar.
  ./configure --prefix=/usr --enable-shared --with-system-expat --without-static-libpython
  make
}

package() {
  cd "Python-$pkgver"
  make DESTDIR="$pkgdir" install
  ln -s python3 "$pkgdir/usr/bin/python"
}
