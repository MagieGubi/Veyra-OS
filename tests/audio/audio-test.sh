#!/usr/bin/env bash
# Tests fuer veyra-audio (packages/base/veyra-audio) ohne Soundkarte: pw-dump, wpctl und pw-play
# sind Attrappen, die festgelegte Antworten geben und ihre Aufrufe protokollieren.
# Muster "Befehl && Pruefung || fail" ist hier gewollt (fail beendet den Test).
# shellcheck disable=SC2015
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
d=$here/packages/base/veyra-audio
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail() { echo "FEHLER: $*" >&2; exit 1; }
n=0
ok() { n=$((n + 1)); echo "ok $n - $*"; }

# Rezept-Pruefsummen passen zu den Dateien
# shellcheck source=packages/base/veyra-audio/recipe.sh
( sources=(); sha256sums=(); . "$d/recipe.sh"
  for i in "${!sources[@]}"; do
    [ "${sha256sums[$i]}" = "$(sha256sum "$d/${sources[$i]}" | cut -d' ' -f1)" ] \
      || fail "sha256sums in $d/recipe.sh passt nicht zu ${sources[$i]}"
  done ) || exit 1
ok "Rezept-Pruefsummen aktuell"

mkdir -p "$t/bin" "$t/run"
: > "$t/run/pipewire-0"
cat > "$t/bin/pw-dump" <<'PW'
#!/bin/sh
cat <<'JSON'
[
 {"id": 30, "type": "PipeWire:Interface:Metadata", "props": {"metadata.name": "default"},
  "metadata": [{"subject": 0, "key": "default.audio.sink", "type": "Spa:String:JSON", "value": {"name": "alsa_output.pci-0000_00_1b.0.analog-stereo"}},
               {"subject": 0, "key": "default.audio.source", "type": "Spa:String:JSON", "value": "{\"name\": \"alsa_input.pci-0000_00_1b.0.analog-stereo\"}"}]},
 {"id": 40, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Audio/Sink", "node.name": "alsa_output.pci-0000_00_1b.0.analog-stereo", "node.description": "Eingebaute Lautsprecher", "device.bus": "pci"},
  "params": {"Props": [{"channelVolumes": [0.064, 0.064], "mute": false}]}}},
 {"id": 41, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Audio/Source", "node.name": "alsa_input.pci-0000_00_1b.0.analog-stereo", "node.description": "Mikrofon"},
  "params": {"Props": [{"channelVolumes": [1.0], "mute": true}]}}},
 {"id": 52, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Audio/Sink", "node.name": "bluez_output.AA_BB.1", "node.description": "Kopfhoerer"}}},
 {"id": 60, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Stream/Output/Audio", "node.name": "firefox"}}}
]
JSON
PW
for c in wpctl pw-play; do
  # shellcheck disable=SC2016  # $* und $1 gehoeren in die Attrappe
  printf '#!/bin/sh\necho "%s $*" >> "%s/aufrufe"\n[ "$1" = get-volume ] && echo "Volume: 0.40"\nexit 0\n' "$c" "$t" > "$t/bin/$c"
done
chmod +x "$t/bin/"*
va() { PATH="$t/bin:$PATH" PIPEWIRE_RUNTIME_DIR="$t/run" python3 "$d/veyra-audio" "$@"; }

va geraete --json > "$t/g.json"
python3 - "$t/g.json" <<'PY' || fail "geraete --json: $(cat "$t/g.json")"
import json, sys
g = {x["id"]: x for x in json.load(open(sys.argv[1]))}
assert set(g) == {40, 41, 52}, g.keys()                     # Stream 60 ist kein Geraet
assert g[40]["art"] == "ausgabe" and g[40]["standard"] and g[40]["lautstaerke"] == 40 and g[40]["stumm"] is False
assert g[41]["art"] == "eingabe" and g[41]["standard"] and g[41]["stumm"] is True   # Wert als JSON-Text
assert g[52]["bus"] == "bluetooth" and not g[52]["standard"] and g[52]["lautstaerke"] is None
PY
ok "geraete --json: Ausgaben, Eingaben, Standard, Lautstaerke (kubisch), Bluetooth"

va geraete | grep -q '^\*   40  ausgabe    40 %        Eingebaute Lautsprecher \[pci\]' || fail "geraete: $(va geraete)"
ok "geraete als Text"

va lautstaerke 30 > /dev/null && grep -q "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 30%" "$t/aufrufe" || fail "lautstaerke 30"
va lautstaerke eingabe +5 > /dev/null && grep -q "@DEFAULT_AUDIO_SOURCE@ 5%+" "$t/aufrufe" || fail "lautstaerke eingabe +5"
if va lautstaerke 200 2>/dev/null; then fail "200 % angenommen"; fi
if va lautstaerke '40;rm' 2>/dev/null; then fail "Unsinn angenommen"; fi
ok "lautstaerke: Ausgabe, Eingabe, relative Werte, Grenzen"

va stumm an > /dev/null && grep -q "wpctl set-mute @DEFAULT_AUDIO_SINK@ 1" "$t/aufrufe" || fail "stumm an"
va stumm 41 aus > /dev/null && grep -q "wpctl set-mute 41 0" "$t/aufrufe" || fail "stumm 41 aus"
ok "stumm"

va standard 52 > /dev/null && grep -q "wpctl set-default 52" "$t/aufrufe" || fail "standard 52"
if va standard 99 2>/dev/null; then fail "unbekannte ID angenommen"; fi
ok "standard nur fuer vorhandene Geraete"

va test --sekunden 0.2 > /dev/null && grep -q "^pw-play .*ton.wav" "$t/aufrufe" || fail "test"
ok "Testton wird erzeugt und abgespielt"

rm "$t/run/pipewire-0"
if va geraete 2> "$t/err"; then fail "ohne PipeWire erfolgreich"; fi
grep -q "kein PipeWire" "$t/err" || fail "Meldung ohne PipeWire: $(cat "$t/err")"
ok "klare Meldung, wenn PipeWire nicht laeuft"

echo "Alle $n Audio-Tests bestanden."
