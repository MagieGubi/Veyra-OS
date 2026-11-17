# Wurzelzertifikate fuer TLS (https): das Mozilla-CA-Buendel, wie es das Python-Projekt
# certifi verteilt. Ohne dieses Paket kann das System keinem oeffentlichen https-Server
# vertrauen (VPKG laedt Netz-Repositories nur ueber https).
# OpenSSL ist mit --openssldir=/etc/ssl gebaut und liest /etc/ssl/cert.pem; der uebliche
# Pfad /etc/ssl/certs/ca-certificates.crt zeigt auf dieselbe Datei.
# Quelle: sdist von PyPI, SHA-256 gegen die Angabe der PyPI-JSON-Schnittstelle geprueft.
# Laden: build/scripts/fetch-extra.sh (vpkg-build selbst laedt nichts herunter).
pkgname=veyra-zertifikate
pkgver=2026.10.23
pkgrel=1
pkgdesc="Wurzelzertifikate (Mozilla-CA-Buendel) fuer https"
license=MPL-2.0
url=https://github.com/certifi/python-certifi
sources=(https://files.pythonhosted.org/packages/fd/11/b524cbd9bbdaca58608e4cf4053fd463417549e1959fa8d3aa18319f9555/certifi-2026.10.23.tar.gz)
sha256sums=(a9895e6e2758b371e0545e321a3a8fd1fcfd9829ada8824a936dfb16aaaf36cd)
depends=(openssl)

package() {
  local s=$srcdir/certifi-$pkgver
  [ "$(grep -c 'BEGIN CERTIFICATE' "$s/certifi/cacert.pem")" -ge 100 ] \
    || { echo "cacert.pem enthaelt zu wenige Zertifikate" >&2; return 1; }
  install -Dm644 "$s/certifi/cacert.pem" "$pkgdir/etc/ssl/certs/ca-certificates.crt"
  ln -s certs/ca-certificates.crt "$pkgdir/etc/ssl/cert.pem"
  install -Dm644 "$s/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
