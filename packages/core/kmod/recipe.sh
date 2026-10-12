pkgname=kmod
pkgver=34.2
pkgdesc="Kernelmodule laden und verwalten"
license=LGPL-2.1-or-later
url=https://github.com/kmod-project/kmod
sources=(https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-34.2.tar.xz)
sha256sums=()
depends=(glibc zlib xz zstd openssl)

build() {
  cd "kmod-$pkgver"
  mkdir build && cd build
  meson setup --prefix=/usr .. --buildtype=release -D manpages=false
  ninja
}

package() {
  cd "kmod-$pkgver/build"
  DESTDIR="$pkgdir" ninja install
}
