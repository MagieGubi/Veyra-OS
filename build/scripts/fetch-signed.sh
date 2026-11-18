#!/usr/bin/env bash
# fetch-signed.sh: laedt Quellen, deren Projekte selbst signieren (ausserhalb von GNU und LFS),
# und prueft sie.
#
# Aufruf: fetch-signed.sh SOURCES.LIST SOURCES.LOCK ZIEL
#
# Zeilen der Liste: URL  SIGNATUR-URL  SCHLUESSEL-URL
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

grep -vE '^\s*(#|$)' "$list" | while read -r url sig keyurl; do
  file=${url##*/}
  [ -f "$dest/$file" ] || { echo ">> Lade $file"; dl "$url" "$dest/$file" || die "Download nicht moeglich: $file"; }
  expected=$(awk -v f="$file" '$2 == f {print $1}' "$lock")
  if [ -n "$expected" ]; then
    echo "$expected  $dest/$file" | sha256sum -c --quiet - || die "SHA-256 passt nicht: $file"
    echo "   ok (sha256) $file"
    continue
  fi
  [ -n "$sig" ] && [ -n "$keyurl" ] || die "$file: Signatur- oder Schluessel-URL fehlt"
  dl "$sig" "$work/$file.sig" || die "Signatur nicht ladbar: $sig"
  dl "$keyurl" "$work/projekt.key" || die "Schluessel nicht ladbar: $keyurl"
  export GNUPGHOME=$work/gnupg; rm -rf "$GNUPGHOME"; mkdir -m 700 "$GNUPGHOME"
  gpg -q --import "$work/projekt.key" 2>/dev/null || die "Schluessel von $keyurl nicht lesbar"
  # Welcher Schluessel hat signiert? (VALIDSIG nennt Unterschluessel und Primaerschluessel)
  st=$(gpg --status-fd 1 --verify "$work/$file.sig" "$dest/$file" 2>/dev/null || true)
  primary=$(echo "$st" | awk '$2 == "VALIDSIG" {print $NF}')
  if [ -z "$primary" ]; then
    echo "   Schluessel aus $keyurl:" >&2; fprs "$work/projekt.key" | sed 's/^/     /' >&2
    echo "   Ausgabe von gpg --verify:" >&2; printf '%s\n' "$st" | while IFS= read -r l; do echo "     $l"; done >&2
    die "GPG-Signatur ungueltig oder nicht vom Schluessel aus $keyurl: $file"
  fi
  dl "https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0x$primary" "$work/keyserver.key" \
    || die "Schluessel $primary nicht auf keyserver.ubuntu.com: zweite Quelle fehlt"
  fprs "$work/keyserver.key" | grep -qx "$primary" || die "keyserver.ubuntu.com liefert einen anderen Schluessel als $primary"
  # Signatur auch nur mit dem Schluessel vom Schluesselserver pruefen
  rm -rf "$GNUPGHOME"; mkdir -m 700 "$GNUPGHOME"
  gpg -q --import "$work/keyserver.key" 2>/dev/null
  gpg --status-fd 1 --verify "$work/$file.sig" "$dest/$file" 2>/dev/null | grep -q " VALIDSIG .* $primary\$" \
    || die "Signatur mit dem Schluessel von keyserver.ubuntu.com nicht gueltig: $file"
  sum=$(sha256sum "$dest/$file" | cut -d' ' -f1)
  echo "$sum  $file" >> "$lock"
  echo "   ok (GPG $primary, Schluessel aus zwei Quellen, neu festgelegt) $file $sum"
done
