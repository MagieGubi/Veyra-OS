#!/usr/bin/env bash
# fetch-sources.sh: laedt Quellen herunter und prueft sie.
#
# Aufruf:
#   fetch-sources.sh [--lock] SOURCES.LIST SOURCES.LOCK ZIELVERZEICHNIS
#
# Ohne --lock: jede Datei MUSS in SOURCES.LOCK stehen und passen, sonst Abbruch.
# Mit --lock:  fehlende Eintraege werden nach erfolgreicher Signaturpruefung
#              berechnet und in SOURCES.LOCK ergaenzt (nur fuer neue Quellen).
#
# Zweites Feld je Zeile (Pruefung vor dem Festlegen):
#   .sig-URL   GNU-Archive, gegen den GNU-Keyring
#   .sign-URL  Kernel, gegen die Schluessel von Linus Torvalds und Greg Kroah-Hartman (WKD)
#   md5:SUMME  Quellen ohne pruefbare Signatur: MD5 aus dem Buch Linux From Scratch 12.4
#              als zweite, unabhaengige Quelle
set -euo pipefail
die() { echo "fetch-sources: $*" >&2; exit 1; }

lock_mode=0
if [ "${1:-}" = "--lock" ]; then lock_mode=1; shift; fi
[ $# -eq 3 ] || die "Aufruf: fetch-sources.sh [--lock] SOURCES.LIST SOURCES.LOCK ZIEL"
list=$1 lock=$2 dest=$3
mkdir -p "$dest"

export GNUPGHOME
GNUPGHOME=$(mktemp -d)
trap 'rm -rf "$GNUPGHOME"' EXIT
keys_ready=0
setup_keys() {
  [ $keys_ready = 1 ] && return
  curl -fsSL --retry 3 -o "$GNUPGHOME/gnu-keyring.gpg" https://ftp.gnu.org/gnu/gnu-keyring.gpg
  gpg -q --import "$GNUPGHOME/gnu-keyring.gpg" 2>/dev/null
  gpg -q --auto-key-locate clear,wkd --locate-keys torvalds@kernel.org gregkh@kernel.org >/dev/null 2>&1 \
    || die "Kernel-Schluessel nicht per WKD abrufbar"
  keys_ready=1
}

grep -vE '^\s*(#|$)' "$list" | while read -r url sig; do
  file=${url##*/}
  if [ ! -f "$dest/$file" ]; then
    echo ">> Lade $file"
    curl -fsSL --retry 3 -o "$dest/$file.part" "$url"
    mv "$dest/$file.part" "$dest/$file"
  fi
  expected=$(awk -v f="$file" '$2 == f {print $1}' "$lock")
  if [ -n "$expected" ]; then
    echo "$expected  $dest/$file" | sha256sum -c --quiet - || die "SHA-256 passt nicht: $file"
    echo "   ok (sha256) $file"
    continue
  fi
  [ $lock_mode = 1 ] || die "$file steht nicht in $lock (erst mit --lock festlegen)"
  [ -n "$sig" ] || die "$file hat keine Signatur; bitte SHA-256 von Hand pruefen und eintragen"
  if [[ $sig == md5:* ]]; then
    echo "${sig#md5:}  $dest/$file" | md5sum -c --quiet - || die "MD5 (LFS) passt nicht: $file"
    sum=$(sha256sum "$dest/$file" | cut -d' ' -f1)
    echo "$sum  $file" >> "$lock"
    echo "   ok (MD5 aus LFS 12.4, neu festgelegt) $file $sum"
    continue
  fi
  setup_keys
  curl -fsSL --retry 3 -o "$dest/${sig##*/}" "$sig"
  case $sig in
    *.sign) xz -cd "$dest/$file" | gpg -q --verify "$dest/${sig##*/}" - 2>/dev/null ;;
    *)      gpg -q --verify "$dest/${sig##*/}" "$dest/$file" 2>/dev/null ;;
  esac || die "GPG-Signatur ungueltig: $file"
  sum=$(sha256sum "$dest/$file" | cut -d' ' -f1)
  echo "$sum  $file" >> "$lock"
  echo "   ok (GPG, neu festgelegt) $file $sum"
done
