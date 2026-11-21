pkgname=lua
pkgver=5.4.9
pkgdesc="Lua 5.4 (Skriptsprache der Regeln von WirePlumber)"
license=MIT
url=https://www.lua.org/
sources=(https://www.lua.org/ftp/lua-5.4.9.tar.gz)
sha256sums=()
depends=(glibc)
makedepends=()

build() {
  cd "lua-$pkgver"
  # Statische Bibliothek mit -fPIC: WirePlumber bindet sie in sein Lua-Modul ein. Lua liefert
  # keine pkg-config-Datei; package() schreibt eine.
  make linux MYCFLAGS="-fPIC"
}

package() {
  cd "lua-$pkgver"
  make INSTALL_TOP="$pkgdir/usr" INSTALL_MAN="$pkgdir/usr/share/man/man1" install
  install -d "$pkgdir/usr/lib/pkgconfig"
  cat > "$pkgdir/usr/lib/pkgconfig/lua.pc" <<PC
prefix=/usr
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: Lua
Description: Lua 5.4
Version: $pkgver
Libs: -L\${libdir} -llua -lm
Libs.private: -ldl
Cflags: -I\${includedir}
PC
  ln -s lua.pc "$pkgdir/usr/lib/pkgconfig/lua5.4.pc"
  ln -s lua.pc "$pkgdir/usr/lib/pkgconfig/lua-5.4.pc"
}
