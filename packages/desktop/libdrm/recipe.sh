pkgname=libdrm
pkgver=2.4.134
pkgdesc="Zugriff auf Kernel-Grafiktreiber (DRM, Modesetting)"
license=MIT
url=https://dri.freedesktop.org/
sources=(https://dri.freedesktop.org/libdrm/libdrm-2.4.134.tar.xz)
sha256sums=()
depends=(glibc)
makedepends=(meson ninja)

build() {
  cd "libdrm-$pkgver"
  # Nur der Kern: Mesa (iris, virgl) braucht keine der herstellerspezifischen Bibliotheken.
  meson setup build --prefix=/usr --buildtype=release -D udev=true -D valgrind=disabled \
    -D tests=false -D man-pages=disabled -D cairo-tests=disabled -D install-test-programs=false \
    -D intel=disabled -D radeon=disabled -D amdgpu=disabled -D nouveau=disabled \
    -D vmwgfx=disabled -D freedreno=disabled -D vc4=disabled -D etnaviv=disabled \
    -D exynos=disabled -D tegra=disabled -D omap=disabled
  ninja -C build
}

package() {
  cd "libdrm-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
}
