pkgname=pkgconf
pkgver=2.5.1
pkgdesc="Verwaltet Compiler- und Linker-Flags (pkg-config)"
license=ISC
url=https://github.com/pkgconf/pkgconf
sources=(https://distfiles.ariadne.space/pkgconf/pkgconf-2.5.1.tar.xz)
sha256sums=()
depends=(glibc)
provides=(pkg-config)

build() {
  cd "pkgconf-$pkgver"
  ./configure --prefix=/usr --disable-static --docdir="/usr/share/doc/pkgconf-$pkgver"
  make
}

package() {
  cd "pkgconf-$pkgver"
  make DESTDIR="$pkgdir" install
  ln -s pkgconf "$pkgdir/usr/bin/pkg-config"
  ln -s pkgconf.1 "$pkgdir/usr/share/man/man1/pkg-config.1"
}
