pkgname=gettext
pkgver=0.26
pkgdesc="Uebersetzungswerkzeuge"
license=GPL-3.0-or-later
url=https://www.gnu.org/software/gettext/
sources=(https://ftp.gnu.org/gnu/gettext/gettext-0.26.tar.xz)
sha256sums=()
depends=(glibc acl ncurses)

build() {
  cd "gettext-$pkgver"
  ./configure --prefix=/usr --disable-static --docdir="/usr/share/doc/gettext-$pkgver"
  make
}

package() {
  cd "gettext-$pkgver"
  make DESTDIR="$pkgdir" install
  chmod 0755 "$pkgdir/usr/lib/preloadable_libintl.so"
}
