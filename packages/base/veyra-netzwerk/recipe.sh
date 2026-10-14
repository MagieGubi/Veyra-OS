# Netzwerk fuer Veyra: kabelgebundene Netzwerkkarten holen sich per DHCP eine Adresse
# (systemd-networkd), Namen loest systemd-resolved auf. WLAN fehlt noch (braucht Firmware
# und einen WLAN-Dienst).
# Eigene Einstellungen gehoeren nach /etc/systemd/network/ (Dateien dort mit gleichem
# Namen ersetzen die hier, kleinere Nummern haben Vorrang).
pkgname=veyra-netzwerk
pkgver=0.1
pkgrel=1
pkgdesc="Netzwerk-Grundeinstellung (DHCP ueber Kabel, Namensaufloesung)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
depends=(systemd)

package() {
  install -d "$pkgdir/usr/lib/systemd/network" "$pkgdir/etc" \
    "$pkgdir/usr/lib/systemd/system/multi-user.target.wants"
  cat > "$pkgdir/usr/lib/systemd/network/89-veyra-kabel.network" <<'NET'
# Veyra: jede kabelgebundene Netzwerkkarte per DHCP (IPv4 und IPv6) einrichten.
# Virtuelle Geraete (Bridges, VPN, Container) sind ausgenommen.
[Match]
Type=ether
Kind=!*

[Network]
DHCP=yes
# Ohne Kabel nicht auf diese Karte warten (systemd-networkd-wait-online).
RequiredForOnline=no

[DHCPv4]
UseDomains=yes
NET
  # Dienste fest einschalten (unabhaengig von systemctl preset).
  for s in systemd-networkd systemd-resolved; do
    ln -s "../$s.service" "$pkgdir/usr/lib/systemd/system/multi-user.target.wants/$s.service"
  done
  # Namensaufloesung ueber den lokalen Stub von systemd-resolved (127.0.0.53).
  ln -s ../run/systemd/resolve/stub-resolv.conf "$pkgdir/etc/resolv.conf"
}
