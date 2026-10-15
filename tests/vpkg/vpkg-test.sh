#!/usr/bin/env bash
# Tests fuer VPKG 0.3 (packages/base/vpkg/vpkg) in einem leeren Zielsystem (--root).
# Braucht python3 (3.11+), zstd, openssl. Laeuft ohne root-Rechte.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
build=$here/build/scripts/vpkg-build
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail() { echo "FEHLER: $*" >&2; exit 1; }
root=$t/root
mkdir -p "$root"
vpkg() { python3 "$here/packages/base/vpkg/vpkg" --root "$root" "$@"; }
n=0
ok() { n=$((n + 1)); echo "ok $n - $*"; }

# Programm und Rezept passen zusammen (sonst scheitert der Paketbau im CI).
want=$(sed -n 's/^sha256sums=(\(.*\))$/\1/p' "$here/packages/base/vpkg/recipe.sh")
[ "$want" = "$(sha256sum "$here/packages/base/vpkg/vpkg" | cut -d' ' -f1)" ] \
  || fail "sha256sums in packages/base/vpkg/recipe.sh passt nicht zum Programm vpkg"
ok "Rezept-Pruefsumme von vpkg aktuell"

# mkpkg NAME VERSION 'depends' 'conflicts' DATEI=INHALT...
mkpkg() {
  local name=$1 ver=$2 deps=$3 confl=$4; shift 4
  local d=$t/r/$name-$ver
  mkdir -p "$d"
  {
    echo "pkgname=$name pkgver=$ver license=MIT"
    echo "depends=($deps) conflicts=($confl)"
    echo 'package() {'
    local kv
    for kv in "$@"; do
      echo "  install -d \"\$pkgdir/$(dirname "${kv%%=*}")\""
      echo "  echo '${kv#*=}' > \"\$pkgdir/${kv%%=*}\""
    done
    echo '}'
  } > "$d/recipe.sh"
  "$build" --srcdir "$t" --outdir "$t/p" "$d" >/dev/null
}
mkpkg liba 1.0 "" "" usr/lib/liba.txt=a1
mkpkg app 1.0 "liba" "" usr/bin/app=app1 usr/share/app/alt.txt=alt etc/app.conf=conf1
mkpkg app 2.0 "liba" "" usr/bin/app=app2 etc/app.conf=conf2
mkpkg dieb 1.0 "" "" usr/lib/liba.txt=fremd
mkpkg rivale 1.0 "" "app" usr/bin/rivale=r
P=$t/p

if vpkg install "$P/app-1.0-1-x86_64.vpkg" 2>/dev/null; then fail "app ohne liba installiert"; fi
[ ! -e "$root/usr/bin/app" ] || fail "Dateien trotz fehlender Abhaengigkeit ausgepackt"
ok "fehlende Abhaengigkeit wird abgelehnt"

vpkg install "$P/app-1.0-1-x86_64.vpkg" "$P/liba-1.0-1-x86_64.vpkg" >/dev/null
[ "$(cat "$root/usr/bin/app")" = app1 ] || fail "Datei von app fehlt"
[ "$(cat "$root/usr/lib/liba.txt")" = a1 ] || fail "Datei von liba fehlt"
[ "$(vpkg list | tr '\n' ' ')" = "app 1.0-1 liba 1.0-1 " ] || fail "list stimmt nicht: $(vpkg list)"
vpkg owner /usr/lib/liba.txt | grep -q 'gehoert zu liba' || fail "owner"
vpkg check >/dev/null || fail "check nach Installation"
ok "Installation mit Abhaengigkeit, list, owner, check"

if vpkg remove liba 2>/dev/null; then fail "liba trotz Abhaengigkeit entfernt"; fi
[ -e "$root/usr/lib/liba.txt" ] || fail "Datei trotz Ablehnung geloescht"
ok "Entfernen einer gebrauchten Abhaengigkeit wird abgelehnt"

if vpkg install "$P/dieb-1.0-1-x86_64.vpkg" 2>/dev/null; then fail "Dateikonflikt nicht erkannt"; fi
[ "$(cat "$root/usr/lib/liba.txt")" = a1 ] || fail "fremde Datei ueberschrieben"
ok "Dateikonflikt mit anderem Paket wird abgelehnt"

if vpkg install "$P/rivale-1.0-1-x86_64.vpkg" 2>/dev/null; then fail "Paketkonflikt nicht erkannt"; fi
ok "Paketkonflikt (conflicts) wird abgelehnt"

mkdir -p "$root/usr/bin" && echo fremd > "$root/usr/bin/rivale-x"
mkpkg ueber 1.0 "" "" usr/bin/rivale-x=neu
if vpkg install "$P/ueber-1.0-1-x86_64.vpkg" 2>/dev/null; then fail "unbekannte Datei ueberschrieben"; fi
vpkg install --overwrite "$P/ueber-1.0-1-x86_64.vpkg" >/dev/null
[ "$(cat "$root/usr/bin/rivale-x")" = neu ] || fail "--overwrite wirkt nicht"
vpkg remove ueber >/dev/null
ok "fremde Datei nur mit --overwrite ersetzt"

echo "meine Einstellung" > "$root/etc/app.conf"
vpkg install "$P/app-2.0-1-x86_64.vpkg" >/dev/null 2>&1
[ "$(cat "$root/usr/bin/app")" = app2 ] || fail "Update nicht ausgepackt"
[ ! -e "$root/usr/share/app/alt.txt" ] || fail "alte Datei nach Update noch da"
[ ! -e "$root/usr/share/app" ] || fail "leeres altes Verzeichnis nach Update noch da"
[ "$(cat "$root/etc/app.conf")" = "meine Einstellung" ] || fail "geaenderte Konfiguration ueberschrieben"
[ "$(cat "$root/etc/app.conf.vpkgnew")" = conf2 ] || fail ".vpkgnew fehlt"
vpkg list | grep -qx 'app 2.0-1' || fail "Version nach Update"
ok "Update entfernt alte Dateien und behaelt geaenderte Konfiguration"

echo kaputt > "$root/usr/lib/liba.txt"
if vpkg check >/dev/null; then fail "check erkennt veraenderte Datei nicht"; fi
vpkg install "$P/liba-1.0-1-x86_64.vpkg" >/dev/null
vpkg check >/dev/null || fail "Neuinstallation repariert nicht"
ok "check erkennt veraenderte Dateien, Neuinstallation repariert"

vpkg remove app liba >/dev/null 2>&1
[ -z "$(vpkg list)" ] || fail "Pakete noch eingetragen"
[ ! -e "$root/usr/bin/app" ] || fail "Datei von app nach remove noch da"
[ ! -e "$root/usr/lib/liba.txt" ] || fail "Datei von liba nach remove noch da"
[ "$(cat "$root/etc/app.conf.vpkgsave")" = "meine Einstellung" ] || fail "geaenderte Konfiguration nicht gesichert"
[ ! -e "$root/usr/lib" ] || fail "leeres Verzeichnis bleibt"
ok "Entfernen raeumt Dateien und leere Verzeichnisse auf, sichert Konfiguration"

mkdir -p "$t/repo"
cp "$P"/liba-1.0-1-x86_64.vpkg "$P"/app-1.0-1-x86_64.vpkg "$t/repo/"
python3 "$here/packages/base/vpkg/vpkg" index "$t/repo" >/dev/null
vpkg install --repo "$t/repo" app >/dev/null
[ "$(vpkg list | tr '\n' ' ')" = "app 1.0-1 liba 1.0-1 " ] || fail "Repository-Installation: $(vpkg list)"
rm "$t/repo/app-1.0-1-x86_64.vpkg"
cp "$P/app-2.0-1-x86_64.vpkg" "$t/repo/"
python3 "$here/packages/base/vpkg/vpkg" index "$t/repo" >/dev/null
mkdir -p "$root/etc/vpkg" && echo "$t/repo" > "$root/etc/vpkg/repo"
vpkg upgrade >/dev/null 2>&1
vpkg list | grep -qx 'app 2.0-1' || fail "upgrade aus dem Repository"
vpkg upgrade | grep -q 'Alles aktuell' || fail "zweites upgrade sollte nichts tun"
echo boese > "$t/repo/liba-1.0-1-x86_64.vpkg.x" && cat "$t/repo/liba-1.0-1-x86_64.vpkg.x" >> "$t/repo/liba-1.0-1-x86_64.vpkg"
if vpkg install --repo "$t/repo" liba 2>/dev/null; then fail "veraendertes Repository-Paket angenommen"; fi
vpkg remove app liba >/dev/null 2>&1
ok "Repository: Abhaengigkeiten aufloesen, upgrade, Pruefsumme aus dem Index"

openssl genpkey -algorithm ed25519 -out "$t/key.pem" 2>/dev/null
mkdir -p "$root/etc/vpkg/keys"
openssl pkey -in "$t/key.pem" -pubout -out "$root/etc/vpkg/keys/veyra.pem"
if vpkg install "$P/liba-1.0-1-x86_64.vpkg" 2>/dev/null; then fail "unsigniertes Paket angenommen"; fi
openssl pkeyutl -sign -inkey "$t/key.pem" -rawin -in "$P/liba-1.0-1-x86_64.vpkg" -out "$P/liba-1.0-1-x86_64.vpkg.sig"
vpkg install "$P/liba-1.0-1-x86_64.vpkg" >/dev/null || fail "signiertes Paket abgelehnt"
cp "$P/liba-1.0-1-x86_64.vpkg.sig" "$P/dieb-1.0-1-x86_64.vpkg.sig"
if vpkg install --overwrite "$P/dieb-1.0-1-x86_64.vpkg" 2>/dev/null; then fail "falsche Signatur angenommen"; fi
vpkg remove liba >/dev/null
rm -r "$root/etc/vpkg/keys"
ok "Signaturen: unsigniert und falsch signiert abgelehnt, richtig signiert angenommen"

mkdir -p "$t/r/skript"
cat > "$t/r/skript/recipe.sh" <<'RCP'
pkgname=skript pkgver=1 license=MIT
package() { install -d "$pkgdir/usr/share/skript"; echo x > "$pkgdir/usr/share/skript/x"; }
post_install() { echo "installiert $pkgname $pkgver" > /var/lib/skript-marker; }
RCP
"$build" --srcdir "$t" --outdir "$P" "$t/r/skript" >/dev/null
"$here/build/scripts/vpkg-verify" "$P/skript-1-1-x86_64.vpkg" >/dev/null || fail "Paket mit Install-Skript abgelehnt"
vpkg install --no-scripts "$P/skript-1-1-x86_64.vpkg" >/dev/null
grep -q 'post_install' "$root/var/lib/vpkg/installed/skript/install" || fail "Install-Skript nicht gespeichert"
vpkg info skript | grep -Eq 'Install-Skript +: ja' || fail "info zeigt Install-Skript nicht"
mkdir "$t/evil" && zstd -q -dc "$P/skript-1-1-x86_64.vpkg" | tar -xf - -C "$t/evil"
echo 'rm -rf /' >> "$t/evil/install"
tar -C "$t/evil" -cf - manifest.toml files install | zstd -q -o "$t/evil.vpkg"
if vpkg install --no-scripts "$t/evil.vpkg" 2>/dev/null; then fail "veraendertes Install-Skript angenommen"; fi
if "$here/build/scripts/vpkg-verify" "$t/evil.vpkg" 2>/dev/null; then fail "vpkg-verify nimmt veraendertes Skript an"; fi
ok "Install-Skript wird mitgeliefert, gespeichert und gegen Manipulation geprueft"

mkdir -p "$t/reg"
zstd -q -dc "$P/liba-1.0-1-x86_64.vpkg" | tar -xf - -C "$t/reg" --strip-components=1 files
python3 "$here/packages/base/vpkg/vpkg" --root "$t/reg" register --strict "$P/liba-1.0-1-x86_64.vpkg" >/dev/null
python3 "$here/packages/base/vpkg/vpkg" --root "$t/reg" check >/dev/null || fail "register + check"
ok "register traegt ausgepackte Pakete ein"

mkdir -p "$t/r/geheim"
cat > "$t/r/geheim/recipe.sh" <<'RCP'
pkgname=geheim pkgver=1 license=MIT
package() { install -d "$pkgdir/usr/libexec"; echo x > "$pkgdir/usr/libexec/helfer"; chmod 4710 "$pkgdir/usr/libexec/helfer"; }
RCP
"$build" --srcdir "$t" --outdir "$P" "$t/r/geheim" >/dev/null
mkdir "$t/repo2" && cp "$P/geheim-1-1-x86_64.vpkg" "$t/repo2/"
python3 "$here/packages/base/vpkg/vpkg" index "$t/repo2" >/dev/null || fail "index mit Modus 4710"
vpkg install "$P/geheim-1-1-x86_64.vpkg" >/dev/null || fail "Installation mit Modus 4710"
[ "$(stat -c %a "$root/usr/libexec/helfer")" = 4710 ] || fail "Modus 4710 nicht uebernommen"
ok "Dateien mit eingeschraenkten Rechten (4710) lassen sich pruefen und installieren"

# ---- Transaktionen (VPKG 0.2): ein abgebrochener Vorgang hinterlaesst das System unveraendert.
tx=$t/tx
mkdir -p "$tx"
vx() { python3 "$here/packages/base/vpkg/vpkg" --root "$tx" "$@"; }
# zustand: Dateibaum (Typ, Rechte, Inhalt) ohne die Paketdatenbank-Sicherungen + list
zustand() {
  (cd "$tx" && find . -path ./var/lib/vpkg/txn -prune -o -printf '%y %m %p\n' | sort
   find . -type f -not -path './var/lib/vpkg/txn/*' -exec sha256sum {} + | sort)
  vx list
}
sauber() {
  [ ! -e "$tx/var/lib/vpkg/txn" ] || fail "$1: /var/lib/vpkg/txn ist liegen geblieben"
  [ -z "$(find "$tx" -name '.vpkg-*')" ] || fail "$1: temporaere Dateien liegen geblieben"
  vx check >/dev/null || fail "$1: check meldet Fehler"
}
vx install "$P/app-1.0-1-x86_64.vpkg" "$P/liba-1.0-1-x86_64.vpkg" >/dev/null
echo lokal > "$tx/etc/app.conf"
vorher=$(zustand)
for k in 0 1 2 3 4 5 6 7 8; do
  if VPKG_TEST_ABBRUCH=fehler:$k vx install "$P/app-2.0-1-x86_64.vpkg" >"$t/out" 2>&1; then
    [ "$k" -gt 0 ] || fail "Update trotz Abbruch bei der 1. Aenderung erfolgreich"
    break   # alle Aenderungen dieses Updates liegen vor k
  fi
  grep -q 'abgebrochen.*das System ist unveraendert' "$t/out" || fail "Meldung nach Abbruch $k: $(cat "$t/out")"
  ! grep -q Traceback "$t/out" || fail "Python-Traceback nach Abbruch $k"
  diff <(echo "$vorher") <(zustand) >&2 || fail "Update mit Abbruch nach $k Aenderung(en) hat das System veraendert"
  sauber "Update mit Abbruch $k"
done
[ "$k" -gt 3 ] || fail "Update hatte zu wenige Aenderungen ($k), Test greift nicht"
vx remove app >/dev/null 2>&1 || true
vx install "$P/app-1.0-1-x86_64.vpkg" >/dev/null
ok "Abbruch an jeder Stelle eines Updates nimmt alles zurueck (Dateien, Konfiguration, Datenbank)"

vorher=$(zustand)
for k in 0 1 2 3 4; do
  if VPKG_TEST_ABBRUCH=fehler:$k vx remove app >"$t/out" 2>&1; then
    fail "Entfernen trotz Abbruch nach $k Aenderung(en) erfolgreich"
  fi
  [ "$(zustand)" = "$vorher" ] || fail "Entfernen mit Abbruch nach $k Aenderung(en) hat das System veraendert"
  sauber "Entfernen mit Abbruch $k"
done
ok "Abbruch beim Entfernen nimmt alles zurueck"

vorher=$(zustand)
set +e
VPKG_TEST_ABBRUCH=absturz:3 vx install "$P/app-2.0-1-x86_64.vpkg" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" = 70 ] || fail "Absturz-Simulation lieferte $rc"
[ -f "$tx/var/lib/vpkg/txn/journal" ] || fail "kein Journal nach Absturz"
[ "$(zustand)" != "$vorher" ] || fail "Absturz-Simulation hat nichts veraendert, Test greift nicht"
if vx check >"$t/out" 2>&1; then fail "check meldet unterbrochenen Vorgang nicht"; fi
grep -q 'unterbrochen' "$t/out" || fail "check-Meldung: $(cat "$t/out")"
vx recover >/dev/null 2>&1 || fail "recover"
[ "$(zustand)" = "$vorher" ] || fail "recover stellt den Zustand nicht wieder her"
sauber "recover"
set +e
VPKG_TEST_ABBRUCH=absturz:5 vx remove app >/dev/null 2>&1
set -e
vx install "$P/app-2.0-1-x86_64.vpkg" >"$t/out" 2>&1 || fail "Installation nach Absturz: $(cat "$t/out")"
grep -q 'unterbrochener Vorgang' "$t/out" || fail "naechster Vorgang hat den Absturz nicht bemerkt"
if [ "$(cat "$tx/usr/bin/app")" != app2 ] || [ "$(vx list | tr '\n' ' ')" != "app 2.0-1 liba 1.0-1 " ]; then
  fail "Zustand nach Wiederherstellung und Update: $(vx list)"
fi
sauber "Update nach Absturz"
ok "Absturz mitten im Vorgang: check meldet ihn, recover oder der naechste Vorgang nimmt ihn zurueck"

if [ "$(id -u)" != 0 ]; then
  mkpkg zwei 1 "" "" usr/bin/zwei=z usr/share/zwei/daten=d
  mkdir -p "$tx/usr/share/zwei"
  chmod 555 "$tx/usr/share/zwei"
  vorher=$(zustand)
  if vx install "$P/zwei-1-1-x86_64.vpkg" >"$t/out" 2>&1; then fail "Installation in schreibgeschuetztes Verzeichnis"; fi
  if ! grep -q '^vpkg: Installation abgebrochen' "$t/out" || grep -q Traceback "$t/out"; then
    fail "Meldung bei fehlenden Rechten: $(cat "$t/out")"
  fi
  [ "$(zustand)" = "$vorher" ] || fail "fehlgeschlagene Installation hat Dateien hinterlassen"
  chmod 755 "$tx/usr/share/zwei"
  sauber "fehlende Rechte"
  ok "echter Schreibfehler (schreibgeschuetztes Verzeichnis): klare Meldung, nichts bleibt liegen"
else
  echo "uebersprungen - Schreibfehler durch fehlende Rechte (laeuft als root, Rechte greifen nicht)"
fi

# ---- Manipulierte Manifeste werden vor jeder Aenderung abgelehnt.
# boese NAME AWK-PROGRAMM: Paket app-1.0 auspacken, Manifest umschreiben, neu packen.
boese() {
  local d=$t/boese/$1
  mkdir -p "$d"
  zstd -q -dc "$P/app-1.0-1-x86_64.vpkg" | tar -xf - -C "$d"
  awk "$2" "$d/manifest.toml" > "$d/m" && mv "$d/m" "$d/manifest.toml"
  (cd "$d" && tar --sort=name -cf - manifest.toml files | zstd -q -o "$t/boese/$1.vpkg")
}
boese rechte '/^mode = "755"/ && !x { print "mode = \"9999\""; x=1; next } { print }'
boese doppelt '{ print } /^\[\[file\]\]/ { n++ } END { print "[[file]]\npath = \"/usr\"\ntype = \"dir\"\nmode = \"755\"" }'
boese datenbank 'END { print "[[file]]\npath = \"/var/lib/vpkg/installed/liba\"\ntype = \"dir\"\nmode = \"755\"" } { print }'
boese unterlink 'END { print "[[file]]\npath = \"/usr/bin/app/x\"\ntype = \"dir\"\nmode = \"755\"" } { print }'
boese pruefsumme '/^sha256 = / && !x { print "sha256 = \"xyz\""; x=1; next } { print }'
boese typ '/^type = "file"/ && !x { print "type = \"fifo\""; x=1; next } { print }'
boese abhaengigkeit '/^depends = / { print "depends = [\"../etc\"]"; next } { print }'
vorher=$(zustand)
for b in rechte doppelt datenbank unterlink pruefsumme typ abhaengigkeit; do
  if vx install "$t/boese/$b.vpkg" >"$t/out" 2>&1; then fail "manipuliertes Manifest ($b) angenommen"; fi
  if ! grep -q '^vpkg: ' "$t/out" || grep -q Traceback "$t/out"; then fail "Manifest $b: $(cat "$t/out")"; fi
  [ "$(zustand)" = "$vorher" ] || fail "manipuliertes Manifest ($b) hat das System veraendert"
done
sauber "Manifeste"
ok "manipulierte Manifeste (Rechte, doppelte Pfade, Paketdatenbank, Pfad unter Datei, Pruefsumme, Typ, Abhaengigkeit) abgelehnt"

# ---- Repository-Sicherheit (VPKG 0.3): signierter Index, Stand, Index-Eintraege, Downgrade.
sr=$t/sr
mkdir -p "$sr/etc/vpkg/keys"
vs() { python3 "$here/packages/base/vpkg/vpkg" --root "$sr" "$@"; }
openssl genpkey -algorithm ed25519 -out "$t/rkey.pem" 2>/dev/null
openssl pkey -in "$t/rkey.pem" -pubout -out "$sr/etc/vpkg/keys/test.pem"
sig() { openssl pkeyutl -sign -inkey "$t/rkey.pem" -rawin -in "$1" -out "$1.sig"; }
# mkrepo VERZ STAND PAKET...: Repository mit signierten Paketen und signiertem Index
mkrepo() {
  local d=$1 st=$2; shift 2
  rm -rf "$d" && mkdir -p "$d"
  local f
  for f in "$@"; do cp "$P/$f" "$d/" && sig "$d/$f"; done
  python3 "$here/packages/base/vpkg/vpkg" index --stand "$st" "$d" >/dev/null
  sig "$d/index.toml"
}
abgelehnt() {   # abgelehnt MELDUNG BEFEHL...: Befehl muss mit MELDUNG scheitern
  local want=$1; shift
  if "$@" >"$t/out" 2>&1; then fail "angenommen statt abgelehnt ($want): $*"; fi
  grep -q "$want" "$t/out" || fail "falsche Meldung (erwartet '$want'): $(cat "$t/out")"
  ! grep -q Traceback "$t/out" || fail "Python-Traceback: $(cat "$t/out")"
}
mkrepo "$t/rp" 100 liba-1.0-1-x86_64.vpkg app-1.0-1-x86_64.vpkg
rm "$t/rp/index.toml.sig"
abgelehnt 'nicht signiert' vs install --repo "$t/rp" app
sig "$t/rp/index.toml"
sed -i 's/^description = ""/description = "anders"/' "$t/rp/index.toml"
abgelehnt 'Signatur des Repository-Index ungueltig' vs install --repo "$t/rp" app
mkrepo "$t/rp" 100 liba-1.0-1-x86_64.vpkg app-1.0-1-x86_64.vpkg
vs install --repo "$t/rp" app >/dev/null || fail "signiertes Repository abgelehnt"
grep -q '"[^"]*rp": 100' "$sr/var/lib/vpkg/repo-stand.json" || fail "Stand nicht gemerkt"
ok "Repository-Index: unsigniert und veraendert abgelehnt, signiert angenommen"

mkrepo "$t/rp" 50 liba-1.0-1-x86_64.vpkg app-2.0-1-x86_64.vpkg
abgelehnt 'aelter als der zuletzt angenommene' vs upgrade --repo "$t/rp"
mkrepo "$t/rp" 200 liba-1.0-1-x86_64.vpkg app-2.0-1-x86_64.vpkg
vs upgrade --repo "$t/rp" >/dev/null || fail "neuerer Index abgelehnt"
vs list | grep -qx 'app 2.0-1' || fail "upgrade mit neuerem Index"
grep -q '"[^"]*rp": 200' "$sr/var/lib/vpkg/repo-stand.json" || fail "neuer Stand nicht gemerkt"
sed -i '/^stand = /d' "$t/rp/index.toml" && sig "$t/rp/index.toml"
abgelehnt 'ohne Stand' vs upgrade --repo "$t/rp"
ok "Repository-Index: aelterer Stand (zurueckgespielte Kopie) und fehlender Stand abgelehnt"

mkrepo "$t/rp" 300 liba-1.0-1-x86_64.vpkg app-2.0-1-x86_64.vpkg dieb-1.0-1-x86_64.vpkg
cp "$t/rp/index.toml" "$t/index.gut"
sed -i 's/^filename = "liba-1.0-1-x86_64.vpkg"/filename = "..\/..\/liba-1.0-1-x86_64.vpkg"/' "$t/rp/index.toml" && sig "$t/rp/index.toml"
abgelehnt 'ungueltiger Dateiname' vs install --repo "$t/rp" liba
# Index-Eintrag liba zeigt auf das Paket dieb (gueltig signiert, aber ein anderes Paket).
dsha=$(sha256sum "$t/rp/dieb-1.0-1-x86_64.vpkg" | cut -d' ' -f1)
python3 - "$t/index.gut" "$t/rp/index.toml" "$dsha" <<'PYX'
import sys
s = open(sys.argv[1]).read()
blk = s.split("\n[[package]]\n")
out = [blk[0]]
for b in blk[1:]:
    if 'name = "liba"' in b:
        b = "\n".join(("filename = \"dieb-1.0-1-x86_64.vpkg\"" if l.startswith("filename") else
                       f"sha256 = \"{sys.argv[3]}\"" if l.startswith("sha256") else l)
                      for l in b.split("\n"))
    out.append(b)
open(sys.argv[2], "w").write("\n[[package]]\n".join(out))
PYX
sig "$t/rp/index.toml"
vs remove app >/dev/null
abgelehnt 'passt nicht zum Repository-Index' vs install --repo "$t/rp" liba
cp "$t/index.gut" "$t/rp/index.toml" && sed -i 's/^sha256 = "\(.\{10\}\).*"/sha256 = "kaputt"/' "$t/rp/index.toml" && sig "$t/rp/index.toml"
abgelehnt 'ungueltige Pruefsumme' vs install --repo "$t/rp" liba
ok "Repository-Index: Pfad im Dateinamen, falsches Paket hinter einem Eintrag und kaputte Pruefsumme abgelehnt"

vs list | grep -qx 'liba 1.0-1' || fail "liba fehlt fuer den Downgrade-Test"
cp "$t/index.gut" "$t/rp/index.toml" && sig "$t/rp/index.toml"
vs install --repo "$t/rp" app >/dev/null || fail "app 2.0 aus dem Repository"
sig "$P/app-1.0-1-x86_64.vpkg"
abgelehnt 'aelter als die installierte Version' vs install "$P/app-1.0-1-x86_64.vpkg"
vs list | grep -qx 'app 2.0-1' || fail "Version nach abgelehntem Downgrade veraendert"
vs install --allow-downgrade "$P/app-1.0-1-x86_64.vpkg" >/dev/null || fail "--allow-downgrade"
vs list | grep -qx 'app 1.0-1' || fail "Downgrade mit --allow-downgrade nicht ausgefuehrt"
ok "aeltere Version wird nur mit --allow-downgrade installiert"

# Die eigenen Pakete (wie im CI-Job "image" gebaut) muessen die Manifestpruefung bestehen;
# vpkg selbst bringt z. B. die leeren Verzeichnisse der Paketdatenbank mit.
mkdir "$t/eigene"
for r in "$here"/packages/base/* "$here"/packages/test/*; do
  "$build" --srcdir "$here" --outdir "$t/eigene" "$r" >/dev/null || fail "Bau von $r"
done
python3 "$here/packages/base/vpkg/vpkg" index "$t/eigene" >"$t/out" 2>&1 \
  || fail "eigene Pakete abgelehnt: $(cat "$t/out")"
ok "eigene Pakete (vpkg, veyra-keyring, veyra-release, Selbsttest) bestehen die Manifestpruefung"

echo "Alle $n VPKG-Tests bestanden."
