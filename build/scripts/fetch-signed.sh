#!/usr/bin/env bash
# fetch-signed.sh: laedt Quellen, deren Projekte selbst signieren (ausserhalb von GNU und LFS),
# und prueft sie.
#
# Aufruf: fetch-signed.sh SOURCES.LIST SOURCES.LOCK ZIEL
#
# Zeilen der Liste: URL  SIGNATUR-URL  SCHLUESSEL-URL  (oder widerruf:URL, siehe pruefe_widerrufen;
#                   oder URL - -: ohne Signatur, nur mit festgeschriebenem SHA-256)
# - Steht die Datei schon in SOURCES.LOCK, zaehlt nur der festgeschriebene SHA-256.
# - Sonst: Schluessel von SCHLUESSEL-URL (Seite des Projekts, https) laden; denselben
#   Fingerabdruck zusaetzlich von keyserver.ubuntu.com holen; nur wenn beide Quellen genau diesen
#   Schluessel liefern und die Signatur mit ihm gueltig ist, wird der SHA-256 in SOURCES.LOCK
#   ergaenzt (mit Fingerabdruck in der Ausgabe, zum Festschreiben im Repository).
set -euo pipefail
die() { echo "fetch-signed: $*" >&2; exit 1; }
[ $# -eq 3 ] || die "Aufruf: fetch-signed.sh SOURCES.LIST SOURCES.LOCK ZIEL"
list=$1 lock=$2 dest=$3
mkdir -p "$dest"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

dl() { curl -fsSL --retry 3 --retry-all-errors --connect-timeout 30 --max-time 900 -o "$2" "$1"; }

# Fingerabdruecke aller Primaer- und Unterschluessel einer Schluesseldatei
fprs() { gpg --with-colons --import-options show-only --import "$1" 2>/dev/null | awk -F: '$1 == "fpr" {print $10}' | sort -u; }

zeige() { printf '%s\n' "$1" | while IFS= read -r l; do echo "     $l"; done >&2; }

# Zweite Quelle keyserver.ubuntu.com: Schluessel mit Fingerabdruck $1 nach $work/keyserver.key
vom_keyserver() {
  dl "https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0x$1" "$work/keyserver.key" \
    || die "Schluessel $1 nicht auf keyserver.ubuntu.com: zweite Quelle fehlt"
  fprs "$work/keyserver.key" | grep -qx "$1" || die "keyserver.ubuntu.com liefert einen anderen Schluessel als $1"
}

# Normalfall: aktueller Schluessel von der Seite des Projekts, gegengeprueft am Schluesselserver
pruefe_aktuell() {
  local keyurl=$1 st
  dl "$keyurl" "$work/projekt.key" || die "Schluessel nicht ladbar: $keyurl"
  gpg -q --import "$work/projekt.key" 2>/dev/null || die "Schluessel von $keyurl nicht lesbar"
  # Welcher Schluessel hat signiert? (VALIDSIG nennt Unterschluessel und Primaerschluessel)
  st=$(gpg --status-fd 1 --verify "$work/$file.sig" "$dest/$file" 2>/dev/null || true)
  primary=$(echo "$st" | awk '$2 == "VALIDSIG" {print $NF}')
  if [ -z "$primary" ]; then
    echo "   Schluessel aus $keyurl:" >&2; zeige "$(fprs "$work/projekt.key")"
    echo "   Ausgabe von gpg --verify:" >&2; zeige "$st"
    die "GPG-Signatur ungueltig oder nicht vom Schluessel aus $keyurl: $file"
  fi
  vom_keyserver "$primary"
  # Signatur auch nur mit dem Schluessel vom Schluesselserver pruefen
  rm -rf "$GNUPGHOME"; mkdir -m 700 "$GNUPGHOME"
  gpg -q --import "$work/keyserver.key" 2>/dev/null
  gpg --status-fd 1 --verify "$work/$file.sig" "$dest/$file" 2>/dev/null | grep -q " VALIDSIG .* $primary\$" \
    || die "Signatur mit dem Schluessel von keyserver.ubuntu.com nicht gueltig: $file"
}

# Aeltere Releases, signiert mit einem inzwischen ersetzten Schluessel: Das Projekt
# veroeffentlicht dafuer nur noch die Widerrufsurkunde. Die ist vom alten Schluessel selbst
# signiert und belegt damit, dass der Schluessel vom Schluesselserver dem Projekt gehoert.
# Angenommen wird nur, wenn der Widerruf "ersetzt" (0x01) oder "nicht mehr genutzt" (0x03)
# lautet und nach der Signatur des Archivs ausgestellt wurde.
pruefe_widerrufen() {
  local revurl=$1 st sigzeit revzeit grund pakete
  st=$(gpg --status-fd 1 --verify "$work/$file.sig" "$dest/$file" 2>/dev/null || true)
  primary=$(echo "$st" | awk '$2 == "ERRSIG" {print $NF}')
  sigzeit=$(echo "$st" | awk '$2 == "ERRSIG" {print $7}')
  [[ $primary =~ ^[0-9A-F]{40}$ ]] || { zeige "$st"; die "Signaturschluessel von $file nicht bestimmbar"; }
  vom_keyserver "$primary"
  gpg -q --import "$work/keyserver.key" 2>/dev/null
  dl "$revurl" "$work/widerruf.asc" || die "Widerrufsurkunde nicht ladbar: $revurl"
  gpg -q --import "$work/widerruf.asc" 2>/dev/null || true
  gpg --with-colons --list-keys "$primary" 2>/dev/null | awk -F: '$1 == "pub" {print $2}' | grep -qx r \
    || die "Widerrufsurkunde von $revurl passt nicht zum Schluessel $primary"
  pakete=$(gpg --list-packets "$work/widerruf.asc" 2>/dev/null)
  revzeit=$(echo "$pakete" | sed -n 's/.*created \([0-9]*\),.*sigclass 0x20.*/\1/p' | head -1)
  grund=$(echo "$pakete" | sed -n 's/.*revocation reason 0x\([0-9a-f]*\).*/\1/p' | head -1)
  case $grund in 01|03) ;; *) die "Schluessel $primary widerrufen mit Grund 0x$grund (nur 01/03 erlaubt)";; esac
  [ -n "$revzeit" ] && [ -n "$sigzeit" ] && [ "$sigzeit" -lt "$revzeit" ] \
    || die "Signatur von $file ($sigzeit) nicht vor dem Widerruf ($revzeit)"
  gpg --status-fd 1 --verify "$work/$file.sig" "$dest/$file" 2>/dev/null | grep -q " VALIDSIG .* $primary\$" \
    || die "Signatur mit dem widerrufenen Schluessel $primary nicht gueltig: $file"
  echo "   Schluessel $primary laut $revurl ersetzt (Grund 0x$grund), Signatur liegt davor"
}

grep -vE '^\s*(#|$)' "$list" | while read -r url sig keyurl; do
  file=${url##*/}
  [ -f "$dest/$file" ] || { echo ">> Lade $file"; dl "$url" "$dest/$file" || die "Download nicht moeglich: $file"; }
  expected=$(awk -v f="$file" '$2 == f {print $1}' "$lock")
  if [ -n "$expected" ]; then
    echo "$expected  $dest/$file" | sha256sum -c --quiet - || die "SHA-256 passt nicht: $file"
    echo "   ok (sha256) $file"
    continue
  fi
  # "-" statt Signatur: das Projekt signiert nicht; dann zaehlt nur ein im Repository
  # festgeschriebener SHA-256 (wie er geprueft wurde, steht in der Liste beim Eintrag).
  [ "$sig" != - ] || die "$file hat keine Signatur und steht nicht in $lock (erst von Hand pruefen und festschreiben)"
  [ -n "$sig" ] && [ -n "$keyurl" ] || die "$file: Signatur- oder Schluessel-URL fehlt"
  dl "$sig" "$work/$file.sig" || die "Signatur nicht ladbar: $sig"
  export GNUPGHOME=$work/gnupg; rm -rf "$GNUPGHOME"; mkdir -m 700 "$GNUPGHOME"
  if [[ $keyurl == widerruf:* ]]; then
    pruefe_widerrufen "${keyurl#widerruf:}"
  else
    pruefe_aktuell "$keyurl"
  fi
  sum=$(sha256sum "$dest/$file" | cut -d' ' -f1)
  echo "$sum  $file" >> "$lock"
  echo "   ok (GPG $primary, Schluessel aus zwei Quellen, neu festgelegt) $file $sum"
done
