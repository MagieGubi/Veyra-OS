# Zugangspunkt-Software. In Veyra nur fuer den WLAN-Test in QEMU (mac80211_hwsim: ein
# virtuelles Funkgeraet als Zugangspunkt mit WPA2-PSK oder WPA3-SAE); keine Gruppe, kein
# Metapaket zieht es nach.
pkgname=hostapd
pkgver=2.12
pkgdesc="hostapd: WLAN-Zugangspunkt (nl80211, WPA2, WPA3-SAE), fuer Tests"
license=BSD-3-Clause
url=https://w1.fi/hostapd/
sources=(https://w1.fi/releases/hostapd-2.12.tar.gz)
sha256sums=()
depends=(glibc libnl openssl)
makedepends=()

build() {
  cd "hostapd-$pkgver/hostapd"
  cat > .config <<'CFG'
CONFIG_DRIVER_NL80211=y
CONFIG_LIBNL32=y
CONFIG_SAE=y
CONFIG_IEEE80211N=y
CONFIG_IEEE80211AC=y
CONFIG_IPV6=y
CONFIG_CTRL_IFACE=y
CFG
  make BINDIR=/usr/bin
}

package() {
  cd "hostapd-$pkgver/hostapd"
  install -Dm755 hostapd "$pkgdir/usr/bin/hostapd"
  install -Dm755 hostapd_cli "$pkgdir/usr/bin/hostapd_cli"
  install -Dm644 ../COPYING "$pkgdir/usr/share/licenses/hostapd/COPYING" 2>/dev/null \
    || install -Dm644 ../README "$pkgdir/usr/share/licenses/hostapd/README"
}
