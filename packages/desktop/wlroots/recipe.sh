pkgname=wlroots
pkgver=0.20.2
pkgdesc="Bausteine fuer Wayland-Compositoren (DRM, libinput, Software-Darstellung)"
license=MIT
url=https://gitlab.freedesktop.org/wlroots/wlroots
sources=(https://gitlab.freedesktop.org/-/project/12103/uploads/6a56af9eafb5240d2823772aeb1e2e7d/wlroots-0.20.2.tar.gz)
sha256sums=()
depends=(glibc systemd libdrm wayland libxkbcommon pixman libinput seatd libdisplay-info)
makedepends=(meson ninja wayland-protocols hwdata)

build() {
  cd "wlroots-$pkgver"
  # Phase 6, Schritt 1: ohne Mesa. Dargestellt wird mit pixman, Bildpuffer sind einfache
  # DRM-Puffer (dumb buffers); GLES2 und GBM kommen mit Mesa. Kein Xwayland.
  meson setup build --prefix=/usr --buildtype=release -D examples=false -D xwayland=disabled \
    -D backends=drm,libinput -D renderers= -D allocators= -D session=enabled \
    -D color-management=disabled -D libliftoff=disabled -D xcb-errors=disabled
  ninja -C build
}

package() {
  cd "wlroots-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
