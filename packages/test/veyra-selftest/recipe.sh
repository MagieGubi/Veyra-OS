# Selbsttest fuer das Entwicklungsabbild: laeuft einmal nach dem Start, prueft die
# Paketdatenbank (vpkg check) und installiert und entfernt das Testpaket vpkg-demo.
# Ergebnis auf der seriellen Konsole: "VEYRA-SELBSTTEST: OK" oder "VEYRA-SELBSTTEST: FEHLER".
# Gibt es die Datenpartition (/mnt/daten, USB-Stick), landen Ergebnis und Kernel-Log
# zusaetzlich dort, damit sie sich unter Windows lesen lassen.
pkgname=veyra-selftest
pkgver=0.2
pkgrel=1
pkgdesc="Selbsttest des Entwicklungsabbilds (nicht fuer echte Systeme)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
depends=(vpkg systemd bash)

package() {
  install -d "$pkgdir/usr/lib/veyra" "$pkgdir/usr/lib/systemd/system"
  cat > "$pkgdir/usr/lib/veyra/selftest.sh" <<'SH'
#!/bin/bash
set -u
bericht=/run/veyra-selbsttest.txt
main() {
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
# Hardware (Phase 6): was erkannt wurde und wie schnell die SSD liest.
m "Kernel: $(uname -r), Root: $(findmnt -no SOURCE /)"
m "CPU:$(grep -m1 '^model name' /proc/cpuinfo | cut -d: -f2-), $(nproc) Threads"
for c in /sys/class/drm/card[0-9]; do
  [ -e "$c/device/driver" ] && m "Grafik: $(basename "$c") Treiber $(basename "$(readlink -f "$c/device/driver")")"
done
m "Netzwerk: $(cd /sys/class/net && echo *)"
# Nur lesen (dd von der Platte nach /dev/null), es wird nichts geschrieben.
for n in /dev/nvme[0-9]n1; do
  [ -b "$n" ] || continue
  m "SSD $n: $(cat "/sys/block/${n#/dev/}/device/model" 2>/dev/null | xargs)"
  m "SSD $n lesen (1 GiB, direkt): $(dd if="$n" of=/dev/null bs=4M count=256 iflag=direct 2>&1 | tail -n 1)"
done
if [ -e /dev/disk/by-partlabel/veyra-daten ]; then
  if mountpoint -q /mnt/daten && touch /mnt/daten/.schreibtest && rm /mnt/daten/.schreibtest; then
    log "Datenpartition: ok (/mnt/daten, Bericht kommt nach veyra-messung.txt)"
  else
    log "Datenpartition: FEHLER (nicht eingehaengt oder nicht beschreibbar)"; fail=1
  fi
fi
if [ $fail = 0 ]; then log OK; else log FEHLER; fi
}
main 2>&1 | tee "$bericht"
if mountpoint -q /mnt/daten; then
  cp "$bericht" /mnt/daten/veyra-messung.txt
  dmesg > /mnt/daten/kernel-log.txt
  sync
fi
SH
  chmod 755 "$pkgdir/usr/lib/veyra/selftest.sh"
  # Start per Timer 20 s nach dem Booten: so gehoert der Test nicht zum Startvorgang,
  # verfaelscht die gemessene Bootzeit nicht und systemd-analyze hat fertige Werte.
  cat > "$pkgdir/usr/lib/systemd/system/veyra-selftest.service" <<'UNIT'
[Unit]
Description=Veyra Selbsttest (Entwicklungsabbild)

[Service]
Type=oneshot
ExecStart=/usr/lib/veyra/selftest.sh
StandardOutput=journal+console
StandardError=journal+console
UNIT
  cat > "$pkgdir/usr/lib/systemd/system/veyra-selftest.timer" <<'UNIT'
[Unit]
Description=Veyra Selbsttest 20 s nach dem Booten

[Timer]
OnBootSec=20s
AccuracySec=1s

[Install]
WantedBy=timers.target
UNIT
  install -d "$pkgdir/usr/lib/systemd/system/timers.target.wants"
  ln -s ../veyra-selftest.timer "$pkgdir/usr/lib/systemd/system/timers.target.wants/veyra-selftest.timer"
}
