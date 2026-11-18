# Netzwerk fuer Veyra: kabelgebundene Netzwerkkarten holen sich per DHCP eine Adresse
# (systemd-networkd), Namen loest systemd-resolved auf. WLAN (seit 0.3): iwd meldet sich am
# Netz an (iwctl oder veyra-network wlan verbinde), die Adresse holt systemd-networkd per
# DHCP. Firmware fuer Intel-WLAN: Paket veyra-firmware-intel-wlan.
# Eigene Einstellungen gehoeren nach /etc/systemd/network/ (Dateien dort mit gleichem
# Namen ersetzen die hier, kleinere Nummern haben Vorrang).
# Sichere Voreinstellung: kein Dienst lauscht im Netz. systemd-resolved beantwortet
# deshalb keine LLMNR- und mDNS-Anfragen (sonst offen auf Port 5355/5353 jeder Karte).
pkgname=veyra-netzwerk
pkgver=0.3
pkgrel=1
pkgdesc="Netzwerk-Grundeinstellung (DHCP ueber Kabel, Namensaufloesung)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-network)
depends=(systemd iwd wireless-regdb)

package() {
  install -d "$pkgdir/usr/lib/systemd/network" "$pkgdir/etc" \
    "$pkgdir/usr/lib/systemd/system/multi-user.target.wants" \
    "$pkgdir/usr/lib/systemd/resolved.conf.d"
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
  cat > "$pkgdir/usr/lib/systemd/network/89-veyra-wlan.network" <<'NET'
# Veyra: WLAN-Karten per DHCP einrichten, sobald iwd verbunden ist.
[Match]
Type=wlan

[Network]
DHCP=yes
IgnoreCarrierLoss=3s
RequiredForOnline=no

[DHCPv4]
UseDomains=yes
NET
  cat > "$pkgdir/usr/lib/systemd/resolved.conf.d/50-veyra.conf" <<'CONF'
# Veyra: Namen nur ueber DNS aufloesen, nicht im lokalen Netz antworten.
[Resolve]
LLMNR=no
MulticastDNS=no
CONF
  # Dienste fest einschalten (unabhaengig von systemctl preset).
  for s in systemd-networkd systemd-resolved iwd; do
    ln -s "../$s.service" "$pkgdir/usr/lib/systemd/system/multi-user.target.wants/$s.service"
  done
  # Namensaufloesung ueber den lokalen Stub von systemd-resolved (127.0.0.53).
  ln -s ../run/systemd/resolve/stub-resolv.conf "$pkgdir/etc/resolv.conf"
}
