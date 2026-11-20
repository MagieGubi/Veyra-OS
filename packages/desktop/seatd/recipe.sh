pkgname=seatd
pkgver=0.9.3
pkgdesc="Sitzverwaltung: gibt Compositoren Zugriff auf Grafik und Eingabe ohne root"
license=MIT
url=https://git.sr.ht/~kennylevinsen/seatd
sources=(https://git.sr.ht/~kennylevinsen/seatd/archive/0.9.3.tar.gz)
sha256sums=()
depends=(glibc)
makedepends=(meson ninja)

build() {
  cd "seatd-$pkgver"
  # Veyra hat kein PAM und damit keine logind-Sitzungen: libseat spricht mit dem Dienst
  # seatd (Gruppe video) oder, fuer root, mit dem eingebauten Sitz.
  meson setup build --prefix=/usr --buildtype=release -D libseat-logind=disabled \
    -D libseat-seatd=enabled -D libseat-builtin=enabled -D server=enabled \
    -D examples=disabled -D man-pages=disabled
  ninja -C build
}

package() {
  cd "seatd-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
  install -d "$pkgdir/usr/lib/systemd/system"
  cat > "$pkgdir/usr/lib/systemd/system/seatd.service" <<'UNIT'
[Unit]
Description=Sitzverwaltung fuer Wayland-Compositoren (seatd)
Documentation=https://git.sr.ht/~kennylevinsen/seatd

[Service]
Type=simple
# Mitglieder der Gruppe video duerfen einen Sitz (Grafik, Eingabe) anfordern.
ExecStart=/usr/bin/seatd -g video
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
UNIT
}
