pkgname=libxcrypt
pkgver=4.4.38
pkgdesc="Moderne Passwort-Hashes (yescrypt)"
license=LGPL-2.1-or-later
url=https://github.com/besser82/libxcrypt
sources=(https://github.com/besser82/libxcrypt/releases/download/v4.4.38/libxcrypt-4.4.38.tar.xz)
sha256sums=()
depends=(glibc)

build() {
  cd "libxcrypt-$pkgver"
  ./configure --prefix=/usr --enable-hashes=strong,glibc --enable-obsolete-api=no \
    --disable-static --disable-failure-tokens
  make
}

package() {
  cd "libxcrypt-$pkgver"
  make DESTDIR="$pkgdir" install
}
