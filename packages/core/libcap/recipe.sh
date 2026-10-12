pkgname=libcap
pkgver=2.76
pkgdesc="POSIX-1003.1e-Capabilities"
license=BSD-3-Clause
url=https://sites.google.com/site/fullycapable/
sources=(https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.76.tar.xz)
sha256sums=()
depends=(glibc attr)

build() {
  cd "libcap-$pkgver"
  sed -i '/install -m.*STA/d' libcap/Makefile
  make prefix=/usr lib=lib
}

package() {
  cd "libcap-$pkgver"
  make prefix=/usr lib=lib DESTDIR="$pkgdir" install
}
