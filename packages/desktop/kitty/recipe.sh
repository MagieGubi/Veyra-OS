# kitty 0.48.2: letzte Version, deren Shader als GLSL beiliegen (ab 0.49 braucht der Bau den
# Shader-Compiler slangc aus shader-slang, ein grosses C++-Projekt; folgt spaeter).
# Die Go-Module fuer kitten laedt build/tools/fetch-gomod.py vor dem chroot nach
# /sources/gomod-kitty-0.48.2 (Proxy-Format); Go prueft jedes Modul gegen go.sum aus dem
# signierten Archiv. Im chroot gibt es kein Netz.
pkgname=kitty
pkgver=0.48.2
pkgdesc="GPU-beschleunigtes Terminal (OpenGL ueber EGL), Standard-Terminal von Veyra"
license=GPL-3.0-only
url=https://sw.kovidgoyal.net/kitty/
sources=(https://github.com/kovidgoyal/kitty/releases/download/v0.48.2/kitty-0.48.2.tar.xz)
sha256sums=()
depends=(glibc python zlib libpng lcms2 xxhash openssl harfbuzz freetype fontconfig cairo pixman wayland libxkbcommon dbus mesa nerd-fonts-symbols dejavu-fonts)
makedepends=(go simde wayland-protocols ncurses)

build() {
  cd "kitty-$pkgver"
  # Veyra hat kein X11: nur das Wayland-Modul von glfw bauen. Mesa ohne GLX hat kein
  # libGL/gl.pc; kitty laedt OpenGL ohnehin zur Laufzeit ueber EGL, gelinkt wird gegen EGL.
  sed -i "s/modules = 'cocoa' if is_macos else 'x11 wayland'/modules = 'cocoa' if is_macos else 'wayland'/" setup.py
  sed -i "s/pkg_config('gl', '--libs')/pkg_config('egl', '--libs')/" setup.py
  grep -q "else 'wayland'$" setup.py && grep -q "pkg_config('egl', '--libs')" setup.py \
    || { echo "kitty: setup.py nicht wie erwartet angepasst" >&2; return 1; }
  # setup.py sucht die eingebaute Symbolschrift ueber fc-list; im chroot ohne fertigen
  # Font-Cache liefert das nichts. Die Datei aus nerd-fonts-symbols direkt hinlegen.
  install -Dm644 /usr/share/fonts/nerd-fonts/SymbolsNerdFontMono-Regular.ttf \
    fonts/SymbolsNerdFontMono-Regular.ttf
  export GOTOOLCHAIN=local GOFLAGS=-mod=mod GOPROXY="file://$srcdir_cache/gomod-kitty-$pkgver" \
    GOSUMDB=off GOCACHE=$srcdir/gocache GOPATH=$srcdir/gopath
  python3 setup.py linux-package --prefix="$srcdir/inst" --update-check-interval=0 --ignore-compiler-warnings --verbose
}

package() {
  install -d "$pkgdir/usr"
  cp -a "$srcdir/inst/." "$pkgdir/usr/"
  [ -x "$pkgdir/usr/bin/kitty" ] && [ -x "$pkgdir/usr/bin/kitten" ] \
    || { echo "kitty oder kitten fehlt" >&2; return 1; }
}
