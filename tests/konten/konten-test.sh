#!/usr/bin/env bash
# Tests fuer die Ersteinrichtung (packages/base/veyra-konten/veyra-einrichtung) und die
# Konten-Pruefung (veyra-kontencheck) in einem kuenstlichen Zielsystem (--root). Braucht root (useradd/usermod -R wechseln per chroot
# hinein), shadow-Werkzeuge und openssl. Aendert nichts am Rechner selbst.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
prog=$here/packages/base/veyra-konten/veyra-einrichtung
check=$here/packages/base/veyra-konten/veyra-kontencheck
[ "$(id -u)" = 0 ] || { echo "konten-test.sh braucht root (sudo)" >&2; exit 1; }
# Rezept und Programme passen zusammen (sonst scheitert der Paketbau im CI).
for f in veyra-einrichtung veyra-kontencheck; do
  grep -q "$(sha256sum "$here/packages/base/veyra-konten/$f" | cut -d' ' -f1)" "$here/packages/base/veyra-konten/recipe.sh" \
    || { echo "nicht ok - sha256sums in packages/base/veyra-konten/recipe.sh passt nicht zu $f" >&2; exit 1; }
done
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
n=0
fail() { echo "nicht ok $n - $1" >&2; exit 1; }
ok() { echo "ok $n - $1"; }

# frisches Zielsystem wie im Testabbild: root gesperrt, Einrichtung noetig
neu() {
  r=$t/r
  rm -rf "$r"
  mkdir -p "$r/etc/veyra" "$r/home" "$r/var/lib" "$r/root"
  printf 'root:x:0:0:root:/root:/bin/bash\nnobody:x:65534:65534:nobody:/:/usr/bin/false\n' > "$r/etc/passwd"
  printf 'root:!*:20000:0:99999:7:::\nnobody:!:20000::::::\n' > "$r/etc/shadow"
  printf 'root:x:0:\nwheel:x:97:\nusers:x:999:\nnogroup:x:65534:\n' > "$r/etc/group"
  printf 'root:::\nwheel:!::\nusers:!::\nnogroup:!::\n' > "$r/etc/gshadow"
  chmod 600 "$r/etc/shadow" "$r/etc/gshadow"
  printf 'UID_MIN 1000\nUID_MAX 60000\nGID_MIN 1000\nGID_MAX 60000\nCREATE_HOME yes\nSU_WHEEL_ONLY yes\n' > "$r/etc/login.defs"
  touch "$r/etc/veyra/einrichtung-noetig"
  echo test > "$r/etc/veyra/variante"
  mkdir -p "$r/tmp" && chmod 1777 "$r/tmp"
  cp "$r/etc/shadow" "$t/shadow.vorher"
}
# laeuft LOG EINGABEZEILEN...: Programm mit diesen Eingaben, Ausgabe nach LOG, Exitcode
laeuft() {
  local log=$1; shift
  printf '%s\n' "$@" | "$prog" --root "$t/r" > "$log" 2>&1
}
# passt BENUTZER PASSWORT: Hash in shadow passt zum Passwort
passt() {
  local h salt
  h=$(awk -F: -v u="$1" '$1 == u {print $2}' "$t/r/etc/shadow")
  case $h in \$6\$*) ;; *) return 1 ;; esac
  salt=$(cut -d'$' -f3 <<<"$h")
  [ "$(printf '%s\n' "$2" | openssl passwd -6 -salt "$salt" -stdin)" = "$h" ]
}
unveraendert() {
  cmp -s "$t/shadow.vorher" "$t/r/etc/shadow" && [ -e "$t/r/etc/veyra/einrichtung-noetig" ] \
    && [ ! -e "$t/r/var/lib/veyra/einrichtung-fertig" ] && ! grep -q '^anna:' "$t/r/etc/passwd"
}

n=$((n + 1)); neu
laeuft "$t/log" 'geheim-root-1' 'geheim-root-1' anna 'geheim-anna-1' 'geheim-anna-1' || { cat "$t/log"; fail "Einrichtung schlug fehl"; }
passt root 'geheim-root-1' || fail "root-Passwort nicht gesetzt"
passt anna 'geheim-anna-1' || fail "Passwort von anna nicht gesetzt"
grep -q '^anna:x:1000:1000::/home/anna:/bin/bash$' "$t/r/etc/passwd" || fail "anna fehlt in passwd: $(grep anna "$t/r/etc/passwd")"
grep -qE '^wheel:x:97:anna$' "$t/r/etc/group" || fail "anna nicht in wheel"
[ -d "$t/r/home/anna" ] && [ "$(stat -c %u "$t/r/home/anna")" = 1000 ] || fail "Home-Verzeichnis fehlt"
[ ! -e "$t/r/etc/veyra/einrichtung-noetig" ] && [ -s "$t/r/var/lib/veyra/einrichtung-fertig" ] || fail "Markierung falsch"
[ "$(stat -c %a "$t/r/etc/shadow")" = 600 ] || fail "Rechte von shadow geaendert: $(stat -c %a "$t/r/etc/shadow")"
if grep -q 'geheim-' "$t/log"; then fail "Passwort in der Ausgabe"; fi
ok "root-Passwort und Benutzer (wheel, Home) gesetzt, Hash passt, Passwort nicht in der Ausgabe"

n=$((n + 1)); neu
laeuft "$t/log" 'kurz' 'langes-pw-9' 'langes-pw-9' '' || { cat "$t/log"; fail "zweiter Versuch schlug fehl"; }
grep -q 'Zu kurz' "$t/log" || fail "kurzes Passwort nicht abgelehnt"
passt root 'langes-pw-9' || fail "root-Passwort nach Wiederholung nicht gesetzt"
[ "$(grep -c . "$t/r/etc/passwd")" = 2 ] || fail "Benutzer angelegt, obwohl keiner verlangt"
ok "zu kurzes Passwort abgelehnt, ohne Benutzer nur root gesetzt"

n=$((n + 1)); neu
if laeuft "$t/log" 'erstes-pw-1' 'anderes-pw-2'; then fail "Abbruch nicht erkannt"; fi
grep -q 'stimmen nicht' "$t/log" || fail "abweichende Wiederholung nicht gemeldet"
unveraendert || fail "nach Abbruch wurde etwas geaendert"
ok "abweichende Wiederholung abgelehnt; Ende der Eingabe bricht ab, nichts geaendert"

n=$((n + 1)); neu
if laeuft "$t/log" 'root-pw-123' 'root-pw-123' 'Anna' '1anna' 'root' 'nobody'; then fail "Abbruch nicht erkannt"; fi
[ "$(grep -c 'Ungueltig' "$t/log")" = 2 ] || fail "ungueltige Namen nicht abgelehnt"
[ "$(grep -c 'gibt es schon' "$t/log")" = 2 ] || fail "vorhandene Namen nicht abgelehnt"
unveraendert || fail "root-Passwort gesetzt, obwohl die Einrichtung abgebrochen wurde"
ok "ungueltige und vorhandene Benutzernamen abgelehnt, Abbruch schreibt nichts"

n=$((n + 1)); neu
laeuft "$t/log" 'root-pw-123' 'root-pw-123' annabell 'annabell' 'anna-pw-456' 'anna-pw-456' || { cat "$t/log"; fail "Einrichtung schlug fehl"; }
grep -q 'nicht der Name sein' "$t/log" || fail "Passwort gleich Name nicht abgelehnt"
passt annabell 'anna-pw-456' || fail "Passwort von annabell falsch"
ok "Passwort gleich Benutzername abgelehnt"

n=$((n + 1))
cp "$t/r/etc/shadow" "$t/shadow.fertig"
laeuft "$t/log" 'neu-root-pw-1' 'neu-root-pw-1' '' || fail "zweiter Aufruf meldet Fehler"
grep -q 'bereits eingerichtet' "$t/log" || fail "zweiter Aufruf nicht erkannt"
cmp -s "$t/shadow.fertig" "$t/r/etc/shadow" || fail "zweiter Aufruf hat shadow geaendert"
ok "nach der Einrichtung aendert ein weiterer Aufruf nichts"

# pruefung ERWARTET-EXIT MUSTER TEXT: veyra-kontencheck auf das Zielsystem
pruefung() {
  n=$((n + 1))
  local rc=0
  "$check" --root "$t/r" > "$t/check" 2>&1 || rc=$?
  [ "$rc" = "$1" ] || { cat "$t/check"; fail "$3: Exitcode $rc statt $1"; }
  grep -qE "$2" "$t/check" || { cat "$t/check"; fail "$3: Meldung '$2' fehlt"; }
  ok "Pruefung: $3"
}
pruefung 0 '^ok: Ersteinrichtung abgeschlossen' "Testabbild nach der Einrichtung"
neu
pruefung 0 '^ok: root gesperrt, Ersteinrichtung steht aus' "frisches Testabbild (root gesperrt, /tmp mit Sticky-Bit)"
sed -i 's/^nobody:!:/nobody::/' "$t/r/etc/shadow"
pruefung 1 '^FEHLER: Konten ohne Passwort: nobody' "Testabbild mit Konto ohne Passwort"
neu; sed -i 's/^root:!\*:/root::/' "$t/r/etc/shadow"
pruefung 1 '^FEHLER: Ersteinrichtung steht aus, aber root ist nicht gesperrt' "Testabbild mit offenem root"
neu; sed -i '/SU_WHEEL_ONLY/d' "$t/r/etc/login.defs"
pruefung 1 '^FEHLER: su ist nicht auf die Gruppe wheel' "Testabbild ohne SU_WHEEL_ONLY"
neu; echo dev > "$t/r/etc/veyra/variante"; sed -i 's/^root:!\*:/root::/' "$t/r/etc/shadow"
pruefung 0 '^ok: ausser root kein Konto ohne Passwort' "Entwicklungsabbild mit root ohne Passwort"
sed -i 's/^nobody:!:/nobody::/' "$t/r/etc/shadow"
pruefung 1 '^FEHLER: Konten ohne Passwort: nobody' "Entwicklungsabbild mit weiterem Konto ohne Passwort"
neu; rm "$t/r/etc/veyra/variante"
pruefung 1 '^FEHLER: Variante unbekannt' "fehlende Variante"
neu; chmod 644 "$t/r/etc/shadow"
pruefung 1 '^FEHLER: /etc/shadow hat Modus/Besitzer 644' "shadow fuer alle lesbar"
neu; echo 'toor:x:0:0::/root:/bin/bash' >> "$t/r/etc/passwd"
pruefung 1 '^FEHLER: weitere Konten mit UID 0: toor' "zweites Konto mit UID 0"
neu; mkdir -p "$t/r/usr/bin" "$t/r/var/offen"; touch "$t/r/usr/bin/x"; chmod 666 "$t/r/usr/bin/x"; chmod 777 "$t/r/var/offen"
pruefung 1 '^FEHLER: fuer alle beschreibbar: .*/usr/bin/x' "fuer alle beschreibbare Datei und Verzeichnis ohne Sticky-Bit"
grep -q '/var/offen' "$t/check" || fail "Verzeichnis ohne Sticky-Bit nicht gemeldet"

echo "Alle $n Konten-Tests bestanden."
