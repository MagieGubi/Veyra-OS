pkgname=libsndfile
pkgver=1.2.2
pkgdesc="Audiodateien lesen und schreiben (WAV und Verwandte; fuer pw-play und pw-record)"
license=LGPL-2.1-or-later
url=https://libsndfile.github.io/libsndfile/
sources=(https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz)
sha256sums=()
depends=(glibc)
makedepends=()

build() {
  cd "libsndfile-$pkgver"
  # Ohne externe Codecs (FLAC, Ogg, Opus, MP3): nur unkomprimierte Formate. GCC 15 nimmt
  # C23 als Standard; der ALAC-Code definiert dort false/bool selbst, darum gnu17.
  CFLAGS="${CFLAGS:-} -std=gnu17" ./configure --prefix=/usr --disable-static --disable-external-libs --disable-mpeg \
    --disable-sqlite --disable-alsa --disable-full-suite
  make
}

package() {
  cd "libsndfile-$pkgver"
  make DESTDIR="$pkgdir" install
}
