# Energieverwaltung fuer Veyra (0.7): veyra-power (Akku, Netzteil, CPU-Energieprofil,
# Ruhezustand), Dienst, der das Profil beim Start und bei jedem Netzteilwechsel anwendet, und
# logind-Einstellungen fuer Deckel und Einschalttaste. Die Dateien liegen neben diesem Rezept;
# bei jeder Aenderung muss sha256sums angepasst werden (tests/power/power-test.sh prueft das).
pkgname=veyra-power
pkgver=0.7
pkgrel=1
pkgdesc="Energie: Akku, CPU-Energieprofil, Ruhezustand (veyra-power)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-laptop)
sources=(veyra-power veyra-power.service 60-veyra-power.rules 50-veyra-power.conf)
sha256sums=(63316b66ccb204e5f312f5fa565de00f38add966d453e3985e74c16b6e5657a7 f573590ae910a709bb52507926f41a3fbaa76d54ed5db533c7b7b29268584222 b4f4393a5b0123421e7142865c7f3bb9550a1a7ad11274d28ebf927e33089555 8e075ad4fbac5fa98c01e0f0f151c68572946ef08f8a2d06cdcbfcbd72f6b400)
depends=(python systemd)

package() {
  install -Dm755 "$srcdir/veyra-power" "$pkgdir/usr/bin/veyra-power"
  install -Dm644 "$srcdir/veyra-power.service" "$pkgdir/usr/lib/systemd/system/veyra-power.service"
  install -Dm644 "$srcdir/60-veyra-power.rules" "$pkgdir/usr/lib/udev/rules.d/60-veyra-power.rules"
  install -Dm644 "$srcdir/50-veyra-power.conf" "$pkgdir/usr/lib/systemd/logind.conf.d/50-veyra-power.conf"
}

post_install() {
  systemctl enable veyra-power.service >/dev/null 2>&1 || true
}

pre_remove() {
  systemctl disable veyra-power.service >/dev/null 2>&1 || true
}
