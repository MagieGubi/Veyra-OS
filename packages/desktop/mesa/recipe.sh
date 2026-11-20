pkgname=mesa
pkgver=26.3.1
pkgdesc="OpenGL und EGL (Software-Treiber softpipe, virgl fuer QEMU, svga fuer VirtualBox und VMware)"
license=MIT
url=https://mesa3d.org/
sources=(https://archive.mesa3d.org/mesa-26.3.1.tar.xz)
sha256sums=()
depends=(glibc libdrm wayland expat zlib zstd)
makedepends=(meson ninja python python-mako python-pyyaml wayland-protocols bison flex)

build() {
  cd "mesa-$pkgver"
  # Ohne LLVM: kein llvmpipe, kein radeonsi; iris (Intel) braucht seit Mesa 25 mesa_clc
  # (LLVM und Clang) und folgt mit dem Desktop 0.8. Nur Wayland, kein GLX (kein X11).
  meson setup build --prefix=/usr --sysconfdir=/etc --buildtype=release \
    -D platforms=wayland -D gallium-drivers=softpipe,virgl,svga -D vulkan-drivers= \
    -D glx=disabled -D egl=enabled -D gbm=enabled -D gles1=disabled -D gles2=enabled \
    -D opengl=true -D glvnd=disabled -D llvm=disabled -D valgrind=disabled \
    -D libunwind=disabled -D video-codecs= -D zstd=enabled -D expat=enabled \
    -D build-tests=false -D microsoft-clc=disabled
  ninja -C build
}

package() {
  cd "mesa-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
  find "$pkgdir" -name libEGL.so.1 | grep -q . || { echo "libEGL fehlt" >&2; return 1; }
}
