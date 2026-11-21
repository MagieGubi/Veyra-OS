pkgname=glib
pkgver=2.90.1
pkgdesc="GLib, GObject und GIO (Grundlage fuer BlueZ, PipeWire und WirePlumber)"
license=LGPL-2.1-or-later
url=https://gitlab.gnome.org/GNOME/glib
sources=(https://download.gnome.org/sources/glib/2.90/glib-2.90.1.tar.xz)
sha256sums=()
depends=(glibc pcre2 libffi zlib util-linux attr)
makedepends=(meson ninja python packaging gettext)

build() {
  cd "glib-$pkgver"
  # Ohne GObject-Introspection (braeuchte ein zweites, verschraenktes Projekt) und ohne Doku.
  meson setup build --prefix=/usr --buildtype=release -D introspection=disabled \
    -D tests=false -D installed_tests=false -D man-pages=disabled -D documentation=false \
    -D sysprof=disabled -D selinux=disabled -D libmount=enabled -D xattr=true \
    -D libelf=disabled -D dtrace=disabled -D systemtap=disabled
  ninja -C build
}

package() {
  cd "glib-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
