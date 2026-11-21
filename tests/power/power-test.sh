#!/usr/bin/env bash
# Tests fuer veyra-power (packages/base/veyra-power) mit nachgebautem /sys eines Laptops
# (Intel-CPU mit intel_pstate, Akku, Netzteil, Plattform-Profil) und Attrappen fuer
# systemctl und systemd-analyze. Den Ruhezustand prueft image/power-test.py in QEMU.
# Muster "Befehl && Pruefung || fail" ist hier gewollt (fail beendet den Test).
# shellcheck disable=SC2015
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
d=$here/packages/base/veyra-power
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail() { echo "FEHLER: $*" >&2; exit 1; }
n=0
ok() { n=$((n + 1)); echo "ok $n - $*"; }

# shellcheck source=packages/base/veyra-power/recipe.sh
( sources=(); sha256sums=(); . "$d/recipe.sh"
  for i in "${!sources[@]}"; do
    [ "${sha256sums[$i]}" = "$(sha256sum "$d/${sources[$i]}" | cut -d' ' -f1)" ] \
      || fail "sha256sums in $d/recipe.sh passt nicht zu ${sources[$i]}"
  done ) || exit 1
ok "Rezept-Pruefsummen aktuell"

s=$t/sys
w() { mkdir -p "$(dirname "$s/$1")"; printf '%s\n' "$2" > "$s/$1"; }
w class/power_supply/AC/type Mains; w class/power_supply/AC/online 0
w class/power_supply/BAT1/type Battery; w class/power_supply/BAT1/status Discharging
w class/power_supply/BAT1/capacity 64; w class/power_supply/BAT1/energy_now 34560000
w class/power_supply/BAT1/energy_full 54000000; w class/power_supply/BAT1/energy_full_design 60000000
w class/power_supply/BAT1/power_now 11520000; w class/power_supply/BAT1/cycle_count 87
w class/power_supply/BAT1/manufacturer MSI; w class/power_supply/BAT1/model_name BTY-M54
w class/power_supply/BAT1/serial_number GEHEIM-AKKU
w class/power_supply/hidpp_battery_0/type Battery; w class/power_supply/hidpp_battery_0/scope Device
for c in 0 1; do
  p=devices/system/cpu/cpufreq/policy$c
  w $p/scaling_driver intel_pstate; w $p/scaling_governor powersave
  w $p/scaling_available_governors "performance powersave"
  w $p/energy_performance_preference balance_performance
  w $p/energy_performance_available_preferences "default performance balance_performance balance_power power"
done
w devices/system/cpu/intel_pstate/no_turbo 0
w firmware/acpi/platform_profile balanced; w firmware/acpi/platform_profile_choices "low-power balanced performance"
w power/state "freeze mem"; w power/mem_sleep "[s2idle] deep"
w power/suspend_stats/success 0; w power/suspend_stats/fail 0
w class/rtc/rtc0/wakealarm ""
mkdir -p "$t/bin"
# shellcheck disable=SC2016  # $* und $1 gehoeren in die Attrappe
printf '#!/bin/sh\necho "$*" >> "%s/aufrufe"\n[ "$1" = suspend ] && echo 1 > "%s/power/suspend_stats/success"\nexit 0\n' "$t" "$s" > "$t/bin/systemctl"
printf '#!/bin/sh\nprintf "[Login]\\nHandleLidSwitch=suspend\\nHandlePowerKey=poweroff\\n"\n' > "$t/bin/systemd-analyze"
chmod +x "$t/bin/"*
vp() { PATH="$t/bin:$PATH" VEYRA_POWER_SYS="$s" VEYRA_POWER_KONF="$t/etc/power.conf" python3 "$d/veyra-power" "$@"; }

out=$(vp status)
grep -q '^Netzteil:      nicht angeschlossen$' <<<"$out" \
  && grep -q '^Akku BAT1:   64 %, entlaedt, noch 3:00 h, 11.5 W$' <<<"$out" \
  && grep -q '^  Zustand:     90 % der urspruenglichen Kapazitaet, 87 Ladezyklen$' <<<"$out" \
  && grep -q '^Profil:        auto (jetzt energiesparen)$' <<<"$out" \
  && grep -q '^CPU:           intel_pstate, Regler powersave, Energievorgabe balance_performance$' <<<"$out" \
  && grep -q '^Ruhezustand:   s2idle (moeglich: s2idle, deep)$' <<<"$out" \
  && grep -q '^Deckel:        suspend, Einschalttaste: poweroff$' <<<"$out" || fail "status: $out"
grep -q hidpp <<<"$out" && fail "Akku einer Maus als Laptop-Akku gezaehlt"
ok "status: Akku mit Restzeit und Abnutzung, Profil, CPU, Ruhezustand, Deckel"

vp status --json > "$t/s.json"
python3 - "$t/s.json" <<'PY' || fail "status --json: $(cat "$t/s.json")"
import json, sys
h = json.load(open(sys.argv[1]))
a = h["akkus"][0]
assert len(h["akkus"]) == 1 and a["ladung"] == 64 and a["restzeit_min"] == 180 and a["zustand_prozent"] == 90
assert h["cpu"]["epp_moeglich"][-1] == "power" and h["plattform"]["profil"] == "balanced"
PY
grep -q GEHEIM "$t/s.json" && fail "Seriennummer ausgegeben"
ok "status --json, keine Seriennummer"

vp profil auto | grep -q '^Profil auto (jetzt energiesparen): CPU-Regler powersave, Energievorgabe power, Plattform-Profil low-power$' \
  || fail "profil auto: $(vp profil auto)"
[ "$(cat "$s/devices/system/cpu/cpufreq/policy1/energy_performance_preference")" = power ] || fail "EPP nicht gesetzt"
grep -qx 'profil=auto' "$t/etc/power.conf" || fail "Profil nicht gespeichert"
ok "profil auto im Akkubetrieb: sparsam, fuer alle CPUs, gespeichert"

w class/power_supply/AC/online 1
out=$(vp anwenden)
grep -q 'ausgewogen: CPU-Regler powersave, Energievorgabe balance_performance, Plattform-Profil balanced' <<<"$out" \
  || fail "anwenden am Netzteil: $out"
ok "Netzteil eingesteckt: auto wird ausgewogen"

out=$(vp profil leistung)
grep -q 'CPU-Regler performance, Plattform-Profil performance$' <<<"$out" || fail "leistung: $out"
[ "$(cat "$s/devices/system/cpu/cpufreq/policy0/scaling_governor")" = performance ] || fail "Regler nicht gesetzt"
[ "$(vp profil)" = leistung ] || fail "profil ohne Namen: $(vp profil)"
ok "profil leistung (EPP bleibt bei performance unberuehrt)"

out=$(vp schlafen --wecken 5 --art deep)
grep -q '^Wieder wach: Ruhezustand deep' <<<"$out" || fail "schlafen: $out"
[ "$(cat "$s/power/mem_sleep")" = deep ] && [ "$(cat "$s/class/rtc/rtc0/wakealarm")" = +5 ] \
  && grep -qx suspend "$t/aufrufe" || fail "schlafen: mem_sleep/wakealarm/systemctl falsch"
out=$(vp schlafen --art shallow 2>&1) && fail "nicht vorhandene Art angenommen"
grep -q 'shallow gibt es hier nicht' <<<"$out" || fail "Meldung: $out"
ok "schlafen: Art, Weckzeit, Erfolg ueber suspend_stats; fehlende Art abgelehnt"

out=$(vp diagnose)
grep -q '===== Status' <<<"$out" && ! grep -q GEHEIM <<<"$out" || fail "diagnose: $out"
ok "diagnose ohne Seriennummern"
echo "Alle $n Energie-Tests bestanden."
