# Firewall fuer Veyra (0.6, Phase 2): nftables-Regeln, die vor dem Netz geladen werden.
# Eingehend: nur Loopback, Antworten auf eigene Verbindungen, noetiges ICMP/ICMPv6, DHCP;
# alles andere wird verworfen. Weiterleiten verboten, ausgehend frei.
# Die Regeln liegen neben diesem Rezept (nftables.conf); bei jeder Aenderung muss sha256sums
# angepasst werden (tests/firewall/firewall-test.sh prueft das).
# Status: systemctl status veyra-firewall; Regeln ansehen: nft list ruleset
pkgname=veyra-firewall
pkgver=0.1
pkgrel=1
pkgdesc="Firewall (nftables): eingehend standardmaessig gesperrt"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(nftables.conf)
sha256sums=(b8c7624566bf673cc763dffaba45d7c13a5124da1b5d8bebde17f5250ce7e143)
depends=(nftables systemd)

package() {
  install -Dm644 "$srcdir/nftables.conf" "$pkgdir/etc/nftables.conf"
  install -d "$pkgdir/usr/lib/systemd/system/sysinit.target.wants"
  cat > "$pkgdir/usr/lib/systemd/system/veyra-firewall.service" <<'UNIT'
[Unit]
Description=Veyra-Firewall (nftables)
Documentation=file:/etc/nftables.conf
DefaultDependencies=no
Wants=network-pre.target
Before=network-pre.target shutdown.target
After=local-fs.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f /etc/nftables.conf
ExecReload=/usr/sbin/nft -f /etc/nftables.conf
ExecStop=/usr/sbin/nft delete table inet veyra
ProtectSystem=full
ProtectHome=yes

[Install]
WantedBy=sysinit.target
UNIT
  ln -s ../veyra-firewall.service "$pkgdir/usr/lib/systemd/system/sysinit.target.wants/veyra-firewall.service"
}
