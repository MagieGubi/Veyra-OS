# Selbsttest fuer das Entwicklungsabbild: laeuft einmal nach dem Start, prueft die
# Paketdatenbank (vpkg check) und installiert und entfernt das Testpaket vpkg-demo.
# Ergebnis auf der seriellen Konsole: "VEYRA-SELBSTTEST: OK" oder "VEYRA-SELBSTTEST: FEHLER".
pkgname=veyra-selftest
pkgver=0.1
pkgrel=1
pkgdesc="Selbsttest des Entwicklungsabbilds (nicht fuer echte Systeme)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
depends=(vpkg systemd bash)

package() {
  install -d "$pkgdir/usr/lib/veyra" "$pkgdir/usr/lib/systemd/system/multi-user.target.wants"
  cat > "$pkgdir/usr/lib/veyra/selftest.sh" <<'SH'
#!/bin/bash
set -u
log() { echo "VEYRA-SELBSTTEST: $*"; }
fail=0
log "Start (vpkg $(vpkg --version | cut -d' ' -f2), $(vpkg list | wc -l) Pakete eingetragen)"
if vpkg check > /run/vpkg-check.log 2>&1; then
  log "vpkg check: $(tail -n 1 /run/vpkg-check.log)"
else
  log "vpkg check meldet Fehler: $(tail -n 1 /run/vpkg-check.log)"
  grep '^FEHLER' /run/vpkg-check.log | head -n 40 | sed 's/^/VEYRA-SELBSTTEST:   /'
  fail=1
fi
demo=$(ls /usr/lib/veyra/selftest/vpkg-demo-*.vpkg)
if vpkg install "$demo" && [ "$(vpkg-demo)" = "vpkg-demo laeuft" ] \
   && grep -q post_install /var/lib/vpkg-demo/marker && vpkg check vpkg-demo >/dev/null; then
  log "vpkg install: ok (Programm laeuft, Install-Skript ausgefuehrt)"
else
  log "vpkg install: FEHLER"; fail=1
fi
if vpkg remove vpkg-demo && [ ! -e /usr/bin/vpkg-demo ] && ! vpkg list | grep -q '^vpkg-demo '; then
  log "vpkg remove: ok"
else
  log "vpkg remove: FEHLER"; fail=1
fi
if [ $fail = 0 ]; then log OK; else log FEHLER; fi
SH
  chmod 755 "$pkgdir/usr/lib/veyra/selftest.sh"
  cat > "$pkgdir/usr/lib/systemd/system/veyra-selftest.service" <<'UNIT'
[Unit]
Description=Veyra Selbsttest (Entwicklungsabbild)
After=multi-user.target serial-getty@ttyS0.service

[Service]
Type=oneshot
ExecStart=/usr/lib/veyra/selftest.sh
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
UNIT
  ln -s ../veyra-selftest.service "$pkgdir/usr/lib/systemd/system/multi-user.target.wants/veyra-selftest.service"
}
