pkgname=fontconfig
pkgver=2.18.1
pkgdesc="Schriftverwaltung (findet und waehlt Schriften)"
license=MIT
url=https://www.freedesktop.org/wiki/Software/fontconfig/
sources=(https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.18.1/fontconfig-2.18.1.tar.xz)
sha256sums=()
depends=(glibc freetype expat)
makedepends=(meson ninja gperf python)

build() {
  cd "fontconfig-$pkgver"
  meson setup build --prefix=/usr --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    -D doc=disabled -D tests=disabled -D tools=enabled -D cache-build=disabled -D nls=disabled
  ninja -C build
}

package() {
  cd "fontconfig-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}

post_install() {
  fc-cache -s >/dev/null 2>&1 || true
}
