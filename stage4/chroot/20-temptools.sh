#!/bin/bash
# Stufe 4a, Teil 2 (in chroot): weitere temporaere Werkzeuge (LFS 12.4, Kapitel 7.7 bis 7.13):
#   gettext (nur Werkzeuge), bison, perl, Python, texinfo, util-linux
# Erwartet die Quellen in /sources und die Skripte in /stage4.
set -euo pipefail
# shellcheck source=stage4/versions.sh
. /stage4/versions.sh
SRC=/sources
build=$(mktemp -d /tmp/veyra-4a.XXXXXX)
trap 'rm -rf "$build"' EXIT
step() { echo; echo "=== $* ==="; }
unpack() { tar -xf "$SRC/$1" -C "$build"; cd "$build/$2"; }

step "gettext $GETTEXT_VER (Werkzeuge)"
unpack "gettext-$GETTEXT_VER.tar.xz" "gettext-$GETTEXT_VER"
./configure --disable-shared
make
cp gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

step "bison $BISON_VER"
unpack "bison-$BISON_VER.tar.xz" "bison-$BISON_VER"
./configure --prefix=/usr --docdir="/usr/share/doc/bison-$BISON_VER"
make
make install

step "perl $PERL_VER"
unpack "perl-$PERL_VER.tar.xz" "perl-$PERL_VER"
sh Configure -des -D prefix=/usr -D vendorprefix=/usr -D useshrplib \
  -D privlib="/usr/lib/perl5/$PERL_SERIES/core_perl" -D archlib="/usr/lib/perl5/$PERL_SERIES/core_perl" \
  -D sitelib="/usr/lib/perl5/$PERL_SERIES/site_perl" -D sitearch="/usr/lib/perl5/$PERL_SERIES/site_perl" \
  -D vendorlib="/usr/lib/perl5/$PERL_SERIES/vendor_perl" -D vendorarch="/usr/lib/perl5/$PERL_SERIES/vendor_perl"
make
make install

step "Python $PYTHON_VER"
unpack "Python-$PYTHON_VER.tar.xz" "Python-$PYTHON_VER"
./configure --prefix=/usr --enable-shared --without-ensurepip --without-static-libpython
make
make install

step "texinfo $TEXINFO_VER"
unpack "texinfo-$TEXINFO_VER.tar.xz" "texinfo-$TEXINFO_VER"
./configure --prefix=/usr
make
make install

step "util-linux $UTIL_LINUX_VER"
unpack "util-linux-$UTIL_LINUX_VER.tar.xz" "util-linux-$UTIL_LINUX_VER"
mkdir -p /var/lib/hwclock
./configure --libdir=/usr/lib --runstatedir=/run \
  --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv \
  --disable-runuser --disable-pylibmount --disable-static --disable-liblastlog2 --without-python \
  ADJTIME_PATH=/var/lib/hwclock/adjtime --docdir="/usr/share/doc/util-linux-$UTIL_LINUX_VER"
make
make install

step "Aufraeumen (LFS 7.13): Doku, libtool-Archive und die Cross-Toolchain /tools entfernen"
cd /
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name '*.la' -delete
rm -rf /tools

step "Pruefung"
for t in bash gcc make perl python3 bison msgfmt makeinfo mount; do
  command -v "$t" >/dev/null || { echo "FEHLER: $t fehlt" >&2; exit 1; }
  echo "   ok $t"
done
python3 -c 'import sys; print("   Python", sys.version.split()[0])'
echo 'int main(void){return 0;}' > /tmp/t.c && gcc /tmp/t.c -o /tmp/t && /tmp/t && rm -f /tmp/t /tmp/t.c
echo "   gcc im Zielsystem baut und startet Programme"
echo
echo "Stufe 4a fertig: das Zielsystem kann sich jetzt selbst weiterbauen."
