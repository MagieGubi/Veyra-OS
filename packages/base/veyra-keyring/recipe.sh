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
sha256sums=(8864857996c1efe48f04ab4661c0575fa97b16a3c35c17a10f9421d29ab2da75)

package() {
  install -Dm644 "$srcdir/veyra-2026.pem" "$pkgdir/etc/vpkg/keys/veyra-2026.pem"
}
