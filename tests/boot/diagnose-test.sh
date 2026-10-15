#!/usr/bin/env bash
# Tests fuer image/boot-diagnose.sh mit kuenstlichen Konsolen-Logs fuer jede Startstufe.
# Braucht nur bash, grep, sed. Laeuft ohne root und ohne QEMU.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
# fall NAME ERWARTET-ERREICHT [ERWARTETER-HINWEIS] < LOG
fall() {
  n=$((n + 1))
  cat > "$t/log"
  out=$("$here/image/boot-diagnose.sh" "$t/log")
  grep -q "^Erreicht: $2" <<<"$out" || { echo "$out"; fail "$1: Stufe '$2' erwartet"; }
  if [ -n "${3:-}" ]; then
    grep -q "^Hinweis: $3" <<<"$out" || { echo "$out"; fail "$1: Hinweis '$3' erwartet"; }
  fi
  echo "ok $n - $1"
}

fall "leeres Log" "nichts" < /dev/null
fall "Firmware findet nichts" "Firmware" "Firmware konnte nichts starten" \
  < <(printf 'BdsDxe: failed to load Boot0001 "UEFI QEMU HARDDISK"\nBdsDxe: No bootable option or device was found.\n')
fall "Root fehlt, Kernel-Panik" "Kernel" "Kernel-Panik" \
  < <(printf '[    0.000000] Linux version 6.18.56-veyra2\n[    1.2] VFS: Unable to mount root fs on unknown-block(0,0)\n[    1.3] Kernel panic - not syncing: VFS: Unable to mount root fs\n')
fall "Live-Init findet das Medium nicht" "Init" "Fehler im Live-Init" \
  < <(printf '[    0.0] Linux version 6.18.56-veyra2\n[    1.0] veyra-live: suche Medium\n[    9.0] veyra-live: FEHLER: Medium nicht gefunden (No such file or directory). Start abgebrochen.\n')
fall "Dienst schlaegt fehl, kein Login" "systemd" "fehlgeschlagene systemd-Einheiten" \
  < <(printf '[    0.0] Linux version 6.18.56-veyra2\n[    1.0] Run /sbin/init as init process\n[    1.1] systemd[1]: systemd 258 running\n[FAILED] Failed to start systemd-networkd.service\n')
fall "Login ohne Selbsttest-Ergebnis" "Login" \
  < <(printf '[    0.0] Linux version 6.18.56-veyra2\n[    1.1] systemd[1]: systemd 258 running\nveyra login: \n')
fall "Selbsttest meldet Fehler" "Selbsttest" "Fehler im Selbsttest" \
  < <(printf '[    0.0] Linux version x\n[    1.1] systemd[1]: x\nveyra login: \n[ 40.0] selftest.sh[228]: VEYRA-SELBSTTEST: Offene Ports: FEHLER (udp 0.0.0.0:5355)\n[ 40.1] selftest.sh[228]: VEYRA-SELBSTTEST: FEHLER\n')
fall "erfolgreicher Start ohne Fehlermuster" "Selbsttest" "keine bekannten Fehlermuster" \
  < <(printf '[    0.0] Linux version x\n[    1.1] systemd[1]: x\nveyra login: \n[ 40.1] selftest.sh[228]: VEYRA-SELBSTTEST: OK\n')
# Zeile aus einem echten CI-Log (Lauf 38697548625): regulatory.db fehlt im Abbild
fall "fehlende Firmware wird gemeldet" "Selbsttest" "fehlende Firmware" \
  < <(printf '[    0.0] Linux version x\n[    0.97] faux_driver regulatory: Direct firmware load for regulatory.db failed with error -2\n[    1.1] systemd[1]: x\nveyra login: \nVEYRA-SELBSTTEST: OK\n')
echo "Alle $n Diagnose-Tests bestanden."
