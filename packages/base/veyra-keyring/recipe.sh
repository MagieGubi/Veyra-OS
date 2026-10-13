# Oeffentlicher Paketschluessel von Veyra OS (Ed25519). VPKG verlangt fuer jedes Paket
# eine gueltige Signatur, sobald ein Schluessel in /etc/vpkg/keys liegt.
# Der private Schluessel liegt nur als GitHub-Secret VPKG_SIGNING_KEY vor.
pkgname=veyra-keyring
pkgver=2026
pkgrel=1
pkgdesc="Oeffentlicher Paketschluessel von Veyra OS"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(veyra-2026.pem)
sha256sums=(1c9bab207b6ccd2de36189a71b718dfd38ee197c4cac59bc30ed075d72753cef)

package() {
  install -Dm644 "$srcdir/veyra-2026.pem" "$pkgdir/etc/vpkg/keys/veyra-2026.pem"
}
