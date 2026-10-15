#!/usr/bin/env bash
# Wertet das Konsolen-Log eines fehlgeschlagenen Starts aus: wie weit der Start kam
# (Firmware, Kernel, Init, systemd, Login, Selbsttest) und welche typischen Fehler im Log
# stehen. Nur lesend, aendert nichts. boot-test.sh ruft es bei jedem Fehlschlag auf; es
# laesst sich auch auf ein Log vom echten Rechner anwenden (Kernel-Log vom USB-Stick).
#
# Aufruf: image/boot-diagnose.sh LOG
set -uo pipefail
log=$1
[ -r "$log" ] || { echo "Diagnose: Log $log nicht lesbar"; exit 0; }

hat() { grep -aqE "$1" "$log"; }
zeige() {   # zeige MUSTER [ANZAHL]: passende Zeilen, hoechstens ANZAHL
  grep -aE "$1" "$log" | head -n "${2:-5}" | cut -c1-200 | sed 's/^/    /'
}

echo "----- Diagnose -----"
if [ ! -s "$log" ]; then
  stufe="nichts: keine Ausgabe auf der seriellen Konsole (QEMU oder Firmware startete nicht)"
elif ! hat 'Linux version'; then
  stufe="Firmware: der Kernel hat nichts ausgegeben (EFI-Datei nicht gefunden oder nicht startbar?)"
elif ! hat 'veyra-live: |Run /[a-z/]*init as init process|systemd\[1\]'; then
  stufe="Kernel: kein Init gestartet (Root-Dateisystem oder Init fehlt?)"
elif ! hat 'systemd\[1\]|Welcome to'; then
  stufe="Init: systemd wurde nicht gestartet"
elif ! hat 'veyra login:'; then
  stufe="systemd: keine Login-Aufforderung"
elif ! hat 'VEYRA-SELBSTTEST: (OK|FEHLER)'; then
  stufe="Login: der Selbsttest hat kein Ergebnis gemeldet"
else
  stufe="Selbsttest: Ergebnis vorhanden"
fi
echo "Erreicht: $stufe"

n=0
pruefe() {   # pruefe TEXT MUSTER: Hinweis mit den passenden Zeilen ausgeben
  if hat "$2"; then
    n=$((n + 1))
    echo "Hinweis: $1"
    zeige "$2"
  fi
}
pruefe "Firmware konnte nichts starten" 'BdsDxe: failed|No bootable option|Boot Failed'
pruefe "Kernel-Panik" 'Kernel panic'
pruefe "Root-Dateisystem nicht eingehaengt" 'VFS: Unable to mount root|Waiting for root device|Cannot open root device'
pruefe "kein Init gefunden" 'No working init found|Failed to execute /[a-z/]*init'
pruefe "Fehler im Live-Init" 'veyra-live: FEHLER'
pruefe "fehlgeschlagene systemd-Einheiten" '\[FAILED\]|Dependency failed|Failed to start'
pruefe "Fehler im Selbsttest" 'VEYRA-SELBSTTEST: .*FEHLER|VEYRA-SELBSTTEST: FEHLER'
pruefe "Ein-/Ausgabefehler am Datentraeger" 'I/O error'
pruefe "fehlende Firmware-Dateien (Paket fehlt noch, ROADMAP P2-3)" 'firmware: failed to load|Direct firmware load for .* failed'
[ $n = 0 ] && echo "Hinweis: keine bekannten Fehlermuster im Log"
echo "Letzte Zeilen:"
tail -n 15 "$log" | cut -c1-200 | sed 's/^/    /'
echo "--------------------"
exit 0
