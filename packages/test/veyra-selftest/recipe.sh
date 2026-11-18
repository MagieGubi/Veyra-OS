# Selbsttest fuer das Entwicklungsabbild: laeuft einmal nach dem Start, prueft die
# Paketdatenbank (vpkg check), installiert und entfernt das Testpaket vpkg-demo und prueft
# Netzwerk, Konten und Rechte (veyra-kontencheck, je nach Variante dev/test) und
# fehlgeschlagene Dienste.
# Ergebnis auf der seriellen Konsole: "VEYRA-SELBSTTEST: OK" oder "VEYRA-SELBSTTEST: FEHLER".
# Gibt es die Datenpartition (/mnt/daten, USB-Stick), landen Ergebnis und Kernel-Log
# zusaetzlich dort, damit sie sich unter Windows lesen lassen.
pkgname=veyra-selftest
pkgver=0.12
pkgrel=1
pkgdesc="Selbsttest des Entwicklungsabbilds (nicht fuer echte Systeme)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
depends=(vpkg veyra-base veyra-network veyra-security veyra-recovery systemd bash iproute2 python veyra-netzwerk veyra-konten veyra-zertifikate veyra-sicherheit veyra-firewall nftables veyra-hwinfo iwd wireless-regdb kmod)

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
# Transaktion (VPKG 0.2): bricht die Installation nach dem Kopieren der Datei ab, darf
# nichts zurueckbleiben (keine Datei, kein Eintrag, kein Journal).
if ! VPKG_TEST_ABBRUCH=fehler:1 vpkg install "$demo" >/run/vpkg-abbruch.log 2>&1 \
   && grep -q 'das System ist unveraendert' /run/vpkg-abbruch.log \
   && [ ! -e /usr/bin/vpkg-demo ] && ! vpkg list | grep -q '^vpkg-demo ' \
   && [ ! -e /var/lib/vpkg/txn ] && vpkg check >/dev/null 2>&1; then
  log "vpkg Abbruch und Ruecknahme: ok"
else
  log "vpkg Abbruch und Ruecknahme: FEHLER ($(tail -n 1 /run/vpkg-abbruch.log))"; fail=1
fi
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
# Netzwerk (Paket veyra-netzwerk): Adresse per DHCP, Router und DNS-Server. In einer VM
# ist das Pflicht (QEMU und VirtualBox bringen ein Netz mit), auf echter Hardware nur ein
# Bericht, weil vielleicht kein Kabel steckt.
virt=$(systemd-detect-virt 2>/dev/null || true)
for d in systemd-networkd systemd-resolved; do
  systemctl is-active -q "$d" || { log "Netzwerk: FEHLER ($d laeuft nicht)"; fail=1; }
done
adr=""
for _ in $(seq 1 30); do
  adr=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $2 " " $4; exit}')
  [ -n "$adr" ] && break
  sleep 1
done
gw=$(ip -4 route show default 2>/dev/null | awk '{print $3; exit}')
dns=$(resolvectl dns 2>/dev/null | grep -oE '([0-9]+\.){3}[0-9]+' | head -n 1)
if [ -n "$adr" ] && [ -n "$gw" ] && [ -n "$dns" ]; then
  log "Netzwerk: ok ($adr per DHCP, Router $gw, DNS $dns)"
elif [ "$virt" != none ] && [ -n "$virt" ]; then
  log "Netzwerk: FEHLER in der VM ($virt): Adresse '${adr}', Router '${gw}', DNS '${dns}'"
  networkctl --no-pager 2>&1 | sed 's/^/VEYRA-SELBSTTEST:   /'
  fail=1
else
  log "Netzwerk: keine Adresse per Kabel (kein Kabel oder nur WLAN, das noch fehlt)"
fi
[ "$(readlink /etc/resolv.conf)" = ../run/systemd/resolve/stub-resolv.conf ] \
  || { log "Netzwerk: FEHLER (/etc/resolv.conf zeigt nicht auf systemd-resolved)"; fail=1; }
# Namensaufloesung braucht Internet; ohne gilt es nicht als Fehler.
if n=$(timeout 15 getent hosts github.com); then
  log "Namensaufloesung: ok (github.com -> $(echo "$n" | awk '{print $1; exit}'))"
else
  log "Namensaufloesung: nicht moeglich (kein Internet?), kein Fehler"
fi
# Wurzelzertifikate (veyra-zertifikate): ohne sie vertraut das System keinem https-Server.
# Mit Internet wird eine echte Verbindung geprueft; ein Zertifikatsfehler ist ein Fehler,
# ein Netzfehler nicht (kein Internet ist kein Fehler des Systems).
tls=$(python3 - <<'PYT' 2>&1
import socket, ssl, sys
ctx = ssl.create_default_context()
n = len(ctx.get_ca_certs())
if n < 100:
    print(f"FEHLER (nur {n} Wurzelzertifikate geladen)"); sys.exit(1)
try:
    with socket.create_connection(("github.com", 443), timeout=10) as s:
        with ctx.wrap_socket(s, server_hostname="github.com") as t:
            print(f"ok ({n} Wurzelzertifikate, github.com per {t.version()} geprueft)")
except ssl.SSLCertVerificationError as e:
    print(f"FEHLER (Zertifikat von github.com nicht geprueft: {e.verify_message})"); sys.exit(1)
except OSError as e:
    print(f"ok ({n} Wurzelzertifikate; github.com nicht erreichbar, kein Fehler: {e})")
PYT
) || fail=1
log "TLS: $tls"
# Nichts darf von aussen erreichbar sein: keine TCP/UDP-Ports ausser auf Loopback. Ausnahme
# sind die Antwort-Ports der DHCP-Clients (UDP 68 fuer IPv4, 546 fuer IPv6).
offen=$(ss -H -tuln 2>/dev/null | awk '{print $1 " " $5}' \
  | grep -vE ' (127\.[0-9.]+(%[[:alnum:]]+)?|\[::1\]|\[::ffff:127\.[0-9.]+\]):[0-9]+$' \
  | grep -vE '^udp .*:(68|546)$' || true)
if [ -z "$offen" ]; then
  log "Offene Ports: ok (nur Loopback)"
else
  log "Offene Ports: FEHLER, von aussen erreichbar: ${offen//$'\n'/, }"
  fail=1
fi
# Konten und Rechte passend zur Variante (Entwicklungs- oder Testabbild).
if veyra-kontencheck > /run/veyra-kontencheck.log 2>&1; then
  log "Konten und Rechte: ok (Variante $(cat /etc/veyra/variante), $(grep -c '^ok:' /run/veyra-kontencheck.log) Pruefungen)"
else
  log "Konten und Rechte: FEHLER"
  grep '^FEHLER' /run/veyra-kontencheck.log | sed 's/^/VEYRA-SELBSTTEST:   /'
  fail=1
fi
if [ -e /etc/veyra/einrichtung-noetig ]; then
  # Im Testabbild wartet die Ersteinrichtung an Konsole 1 auf Eingaben.
  if systemctl is-active -q veyra-einrichtung.service; then
    log "Ersteinrichtung: wartet an Konsole 1 auf das root-Passwort"
  else
    log "Ersteinrichtung: FEHLER (Dienst laeuft nicht: $(systemctl is-active veyra-einrichtung.service))"; fail=1
  fi
fi
# Firewall (veyra-firewall): Dienst aktiv, eingehend und Weiterleiten verwerfen.
if ! systemctl is-active -q veyra-firewall.service; then
  log "Firewall: FEHLER (veyra-firewall.service: $(systemctl is-active veyra-firewall.service))"; fail=1
elif ! nft list chain inet veyra eingang 2>/dev/null | grep -q 'policy drop;' \
     || ! nft list chain inet veyra weiterleiten 2>/dev/null | grep -q 'policy drop;'; then
  log "Firewall: FEHLER (Regeln geladen, aber eingehend oder Weiterleiten nicht auf drop)"; fail=1
else
  log "Firewall: ok (nftables, eingehend und Weiterleiten verworfen, $(nft list ruleset | grep -c accept) Ausnahmen)"
fi
# Paketgruppen (VPKG 0.6): die Metapakete sind installiert und tragen ihre Gruppe.
gr=""
for g in veyra-base veyra-network veyra-security veyra-recovery; do
  vpkg info "$g" 2>/dev/null | grep -q "^Gruppen *: $g\$" || gr="$gr $g"
done
if [ -n "$gr" ]; then
  log "Paketgruppen: FEHLER (Metapaket fehlt oder ohne Gruppe:$gr)"; fail=1
else
  log "Paketgruppen: ok ($(vpkg --version), Metapakete veyra-base, -network, -security, -recovery)"
fi
# Hardware-Erkennung (veyra-hwinfo): JSON gueltig, Threads wie nproc, Speicher und ein
# Netzwerkadapter mit Treiber erkannt (die VM hat immer einen).
if hw=$(veyra-hwinfo --json 2>&1) && echo "$hw" | python3 -c '
import json, os, sys
h = json.load(sys.stdin)
assert h["cpu"]["threads"] == os.cpu_count(), "Threads"
assert h["speicher"]["gesamt_mib"] > 0, "Speicher"
assert any(n["treiber"] for n in h["netzwerk"]), "Netzwerkadapter"
c, m, p, o = h["cpu"]["threads"], h["speicher"]["gesamt_mib"], len(h["pci"]), len(h["ohne_treiber"])
print(f"{c} Threads, {m} MiB, {p} PCI-Geraete, {o} ohne Treiber")' > /run/veyra-hwinfo.txt 2>&1; then
  log "Hardware: ok ($(cat /run/veyra-hwinfo.txt))"
else
  log "Hardware: FEHLER ($(tail -n 1 /run/veyra-hwinfo.txt 2>/dev/null))"; fail=1
fi
# Netzwerkwerkzeug (veyra-network): die Netzwerkkarte der VM erscheint, die Diagnose laeuft
# und enthaelt keine MAC-Adresse.
if ! veyra-network geraete 2>&1 | grep -q 'Ethernet'; then
  log "veyra-network: FEHLER (keine Ethernet-Karte in veyra-network geraete)"; fail=1
elif veyra-network diagnose > /run/veyra-network-diagnose.txt 2>&1 \
     && ! grep -qE '([0-9a-f]{2}:){5}[0-9a-f]{2}' /run/veyra-network-diagnose.txt; then
  log "veyra-network: ok ($(veyra-network geraete | head -n 1 | tr -s ' '), Diagnose ohne MAC-Adressen)"
else
  log "veyra-network: FEHLER (Diagnose gescheitert oder mit MAC-Adresse)"; fail=1
fi
# WLAN (iwd, Phase 5): iwd laeuft auch ohne WLAN-Geraet. In einer VM zusaetzlich mit einem
# virtuellen Funkgeraet (mac80211_hwsim): iwd erkennt es, regulatory.db ist ladbar.
if ! systemctl is-active -q iwd.service; then
  log "WLAN: FEHLER (iwd.service: $(systemctl is-active iwd.service))"; fail=1
elif systemd-detect-virt -q && modprobe mac80211_hwsim radios=1 2>/dev/null; then
  gesehen=""
  for _ in $(seq 20); do
    gesehen=$(iwctl device list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -o 'wlan[0-9]*' | head -n 1)
    [ -n "$gesehen" ] && break
    sleep 0.5
  done
  if [ -z "$gesehen" ]; then
    log "WLAN: FEHLER (iwd erkennt das virtuelle Funkgeraet nicht)"; fail=1
  elif journalctl -k -b --no-pager | grep -q 'failed to load regulatory.db'; then
    log "WLAN: FEHLER (regulatory.db nicht ladbar)"; fail=1
  else
    log "WLAN: ok (iwd $(iwd --version 2>/dev/null || /usr/lib/iwd/iwd --version), virtuelles Geraet $gesehen erkannt, regulatory.db ok)"
  fi
  modprobe -r mac80211_hwsim 2>/dev/null || true
else
  log "WLAN: ok (iwd laeuft, kein Test mit virtuellem Funkgeraet)"
fi
# Kernel-Haertung (veyra-sicherheit, Kernel-Fragmente veyra-50/60): jeder sysctl-Wert aus der
# Paketdatei muss im laufenden System gelten, Yama muss aktiv sein, nftables im Kernel.
if [ -f /usr/lib/sysctl.d/50-veyra-sicherheit.conf ]; then
  falsch=""; n=0
  while IFS='=' read -r k v; do
    k=$(echo "$k" | tr -d ' '); v=$(echo "$v" | tr -d ' ')
    case $k in ''|'#'*) continue ;; esac
    n=$((n + 1))
    ist=$(sysctl -n "$k" 2>/dev/null || echo fehlt)
    [ "$ist" = "$v" ] || falsch="$falsch $k=$ist(soll $v)"
  done < /usr/lib/sysctl.d/50-veyra-sicherheit.conf
  lsm=$(cat /sys/kernel/security/lsm 2>/dev/null || echo "")
  case ",$lsm," in *,yama,*) ;; *) falsch="$falsch LSM-ohne-yama($lsm)" ;; esac
  zgrep -qx 'CONFIG_NF_TABLES=y' /proc/config.gz 2>/dev/null || falsch="$falsch CONFIG_NF_TABLES-fehlt"
  if [ -z "$falsch" ]; then
    log "Kernel-Haertung: ok ($n sysctl-Werte, LSM $lsm, nftables im Kernel)"
  else
    log "Kernel-Haertung: FEHLER:$falsch"; fail=1
  fi
else
  log "Kernel-Haertung: FEHLER (veyra-sicherheit nicht installiert)"; fail=1
fi
# Kein Dienst darf beim Start fehlgeschlagen sein.
kaputt=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
if [ -z "$kaputt" ]; then
  log "Dienste: ok (keiner fehlgeschlagen)"
else
  log "Dienste: FEHLER, fehlgeschlagen: ${kaputt//$'\n'/ }"
  for u in $kaputt; do
    journalctl -b -u "$u" -n 5 --no-pager 2>&1 | sed 's/^/VEYRA-SELBSTTEST:   /'
  done
  fail=1
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
