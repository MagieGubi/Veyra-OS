pkgname=kbd
pkgver=2.8.0
pkgdesc="Tastaturbelegungen und Konsolenschriften"
license=GPL-2.0-or-later
url=https://kbd-project.org
sources=(https://www.kernel.org/pub/linux/utils/kbd/kbd-2.8.0.tar.xz
         https://www.linuxfromscratch.org/patches/lfs/12.4/kbd-2.8.0-backspace-1.patch)
sha256sums=()
depends=(glibc)

build() {
  cd "kbd-$pkgver"
  patch -Np1 -i ../kbd-2.8.0-backspace-1.patch
  sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
  sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
  ./configure --prefix=/usr --disable-vlock
  make
}

package() {
  cd "kbd-$pkgver"
  make DESTDIR="$pkgdir" install
}
