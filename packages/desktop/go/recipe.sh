# Go aus Quellen, ohne fremdes Go-Binary: Kette 1.4 (C-Quellen, mit GCC gebaut) -> 1.17 ->
# 1.20 -> 1.22 -> 1.24 -> 1.26 (jede Version braucht laut ihrem cmd/dist eine Mindestversion
# zum Bauen; Go 1.26 verlangt 1.24.6). Wie Buildroot (package/go/go-bootstrap-stage*).
# Nur fuer den Bau (kitten in kitty); installiert wird nur Go 1.26.
# vpkg-build packt alle Quellen nach $srcdir aus, sie liegen dort alle unter go/; deshalb
# entpackt build() jede Stufe noch einmal einzeln aus dem Quellverzeichnis ($srcdir_cache,
# dieselben Dateien, deren SHA-256 vpkg-build gerade geprueft hat).
pkgname=go
pkgver=1.26.11
pkgdesc="Go-Compiler (nur fuer den Bau von kitty)"
license=BSD-3-Clause
url=https://go.dev/
sources=(https://dl.google.com/go/go1.4-bootstrap-20171003.tar.gz
         https://go.dev/dl/go1.17.13.src.tar.gz
         https://go.dev/dl/go1.20.14.src.tar.gz
         https://go.dev/dl/go1.22.12.src.tar.gz
         https://go.dev/dl/go1.24.13.src.tar.gz
         https://go.dev/dl/go1.26.11.src.tar.gz)
sha256sums=()
depends=(glibc)

build() {
  local b=$srcdir/kette v prev
  rm -rf "$srcdir/go"
  mkdir -p "$b"
  export CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOTOOLCHAIN=local GOCACHE=$srcdir/cache \
    GOPATH=$srcdir/gopath GO111MODULE=off
  unset GOROOT GOBIN
  mkdir "$b/1.4"
  tar -xf "$srcdir_cache/go1.4-bootstrap-20171003.tar.gz" -C "$b/1.4" --strip-components=1
  # Go 1.4 ist C-Code von 2014: mit GCC 15 nur als gnu99 (C23 ist Standard), wie Buildroot.
  ( cd "$b/1.4/src" && CC="gcc -std=gnu99" ./make.bash )
  prev=$b/1.4
  for v in 1.17.13 1.20.14 1.22.12 1.24.13; do
    mkdir "$b/$v"
    tar -xf "$srcdir_cache/go$v.src.tar.gz" -C "$b/$v" --strip-components=1
    ( cd "$b/$v/src" && GOROOT_BOOTSTRAP=$prev ./make.bash )
    prev=$b/$v
  done
  mkdir "$srcdir/go"
  tar -xf "$srcdir_cache/go$pkgver.src.tar.gz" -C "$srcdir/go" --strip-components=1
  ( cd "$srcdir/go/src" && GOROOT_BOOTSTRAP=$prev GO111MODULE= ./make.bash )
  "$srcdir/go/bin/go" version
}

package() {
  local d=$pkgdir/usr/lib/go
  install -d "$d" "$pkgdir/usr/bin"
  cp -a "$srcdir/go"/{bin,lib,misc,pkg,src,VERSION,go.env,LICENSE} "$d/"
  rm -rf "$d/pkg/obj" "$d/pkg/bootstrap"
  ln -s ../lib/go/bin/go "$pkgdir/usr/bin/go"
  ln -s ../lib/go/bin/gofmt "$pkgdir/usr/bin/gofmt"
}
