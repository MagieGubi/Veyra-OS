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
if ls /etc/vpkg/keys/*.pem >/dev/null 2>&1; then
  cp "$demo" /run/unsigniert.vpkg
  if vpkg install /run/unsigniert.vpkg >/dev/null 2>&1; then
    log "Signaturpruefung: FEHLER (unsigniertes Paket angenommen)"; fail=1
    vpkg remove vpkg-demo >/dev/null 2>&1
  else
    log "Signaturpruefung: ok (alle Pakete signiert, unsigniertes Paket abgelehnt)"
  fi
else
  log "Signaturpruefung: keine Schluessel eingerichtet (Pakete unsigniert)"
fi
# Messwerte (Phase 6, hier nur in der VM): erst nach den Tests, damit vpkg nicht mitzaehlt.
m() { echo "VEYRA-MESSUNG: $*"; }
m "$(systemd-analyze time 2>&1 | head -n 1)"
systemd-analyze blame 2>/dev/null | head -n 5 | sed 's/^ */VEYRA-MESSUNG:   langsam: /'
m "Speicher belegt: $(free -m | awk '/^Mem:/ {print $3}') MiB von $(free -m | awk '/^Mem:/ {print $2}') MiB"
m "Prozesse: $(ps -e --no-headers | wc -l), davon Kernel-Threads: $(ps -e -o ppid= | awk '$1 == 2' | wc -l)"
m "Root-Dateisystem belegt: $(df -m / | awk 'NR == 2 {print $3}') MiB"
m "Laufende Dienste: $(systemctl list-units --type=service --state=running --no-legend | wc -l)"
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
