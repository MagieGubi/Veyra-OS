pkgname=pipewire
pkgver=1.6.6
pkgdesc="PipeWire: Audio-Server mit ALSA-, PulseAudio- und Bluetooth-Unterstuetzung"
license=MIT
url=https://pipewire.org/
sources=(https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/1.6.6/pipewire-1.6.6.tar.bz2)
sha256sums=()
depends=(glibc dbus systemd alsa-lib libsndfile sbc readline)
makedepends=(meson ninja python)

build() {
  cd "pipewire-$pkgver"
  # Alles Automatische aus, nur das Noetige an. Veyra hat kein PAM und damit keine
  # Benutzer-Sitzungen von systemd: PipeWire laeuft als Systemdienst (Benutzer pipewire,
  # Socket in /run/pipewire), siehe Paket veyra-audio. Die Sitzungsverwaltung ist
  # WirePlumber als eigenes Paket (session-managers leer, sonst holte meson ein Unterprojekt).
  meson setup build --prefix=/usr --buildtype=release -D auto_features=disabled \
    -D session-managers=[] -D docs=disabled -D man=disabled -D tests=disabled \
    -D installed_tests=disabled -D examples=disabled \
    -D dbus=enabled -D libsystemd=enabled -D udev=enabled \
    -D systemd-system-service=enabled -D systemd-user-service=disabled \
    -D systemd-system-unit-dir=/usr/lib/systemd/system \
    -D spa-plugins=enabled -D alsa=enabled -D pipewire-alsa=enabled \
    -D audiomixer=enabled -D audioconvert=enabled -D audiotestsrc=enabled \
    -D control=enabled -D support=enabled -D volume=enabled \
    -D pw-cat=enabled -D sndfile=enabled -D readline=enabled \
    -D bluez5=enabled -D bluez5-backend-hsp-native=enabled -D bluez5-backend-hfp-native=enabled
  ninja -C build
}

package() {
  cd "pipewire-$pkgver"
  DESTDIR="$pkgdir" ninja -C build install
  [ -x "$pkgdir/usr/bin/pipewire" ] && [ -x "$pkgdir/usr/bin/pw-play" ] \
    && [ -x "$pkgdir/usr/bin/pipewire-pulse" ] \
    && [ -f "$pkgdir/usr/lib/systemd/system/pipewire.service" ] \
    || { echo "pipewire: erwartete Dateien fehlen" >&2; return 1; }
  ls "$pkgdir"/usr/lib/spa-0.2/bluez5/*.so >/dev/null \
    || { echo "pipewire: Bluetooth-Modul fehlt" >&2; return 1; }
}
