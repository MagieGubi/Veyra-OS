pkgname=freetype
pkgver=2.15.0
pkgdesc="Schriftdarstellung (TrueType, OpenType)"
license=FTL
url=https://freetype.org/
sources=(https://download.savannah.gnu.org/releases/freetype/freetype-2.15.0.tar.xz)
sha256sums=()
depends=(glibc zlib bzip2)

build() {
  cd "freetype-$pkgver"
  # Ohne harfbuzz, libpng und brotli (farbige Emoji und WOFF2 folgen mit dem Desktop 0.8).
  ./configure --prefix=/usr --disable-static --enable-freetype-config \
    --with-zlib=yes --with-bzip2=yes --with-png=no --with-harfbuzz=no --with-brotli=no
  make
}

package() {
  cd "freetype-$pkgver"
  make DESTDIR="$pkgdir" install
}
