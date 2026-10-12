pkgname=openssl
pkgver=3.5.2
pkgdesc="TLS und Kryptografie"
license=Apache-2.0
url=https://www.openssl.org
sources=(https://github.com/openssl/openssl/releases/download/openssl-3.5.2/openssl-3.5.2.tar.gz)
sha256sums=()
depends=(glibc zlib)

build() {
  cd "openssl-$pkgver"
  ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
  make
}

package() {
  cd "openssl-$pkgver"
  sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
  # Ohne die umfangreiche Handbuch-Doku (minimal by default)
  make DESTDIR="$pkgdir" install_sw install_ssldirs
}
