#!/usr/bin/env bash
# Tests fuer VPKG 0.1 (packages/base/vpkg/vpkg) in einem leeren Zielsystem (--root).
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

echo "Alle $n VPKG-0.1-Tests bestanden."
