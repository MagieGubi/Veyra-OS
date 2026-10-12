# VPKG-Paketformat (Version 1)

Stand: Core 0.1. Dieses Format erzeugt `vpkg-build` schon heute; das spätere VPKG 0.1
(Installieren, Entfernen, Abhängigkeiten) liest genau dieses Format.

## Paketdatei

`NAME-VERSION-RELEASE-ARCH.vpkg` ist ein mit zstd komprimiertes POSIX-tar-Archiv:

```
manifest.toml     Metadaten und Dateiliste
files/            Dateien, so wie sie ab / installiert werden
```

Das Archiv ist reproduzierbar: Einträge sortiert, Besitzer 0:0, alle Zeitstempel =
`SOURCE_DATE_EPOCH`, zstd Stufe 19 mit einem Thread. Gleiches Rezept + gleiche Quellen
ergeben dieselbe Datei (geprüft in `tests/vpkg/run.sh`).

Signatur: `PAKET.vpkg.sig` enthält eine Ed25519-Signatur über die ganze `.vpkg`-Datei
(OpenSSL `pkeyutl -rawin`). Der private Schlüssel liegt nie im Repository.

## manifest.toml

```toml
format = 1
name = "veyra-release"
version = "0.1"
release = 1
arch = "x86_64"
description = "..."
license = "MIT"
url = "..."
depends = []          # Laufzeitabhängigkeiten (Paketnamen)
makedepends = []      # Build-Abhängigkeiten
conflicts = []
provides = []
recipe_sha256 = "..." # Hash von recipe.sh = Herkunftsnachweis
build_date = 0        # SOURCE_DATE_EPOCH

[[source]]            # je Quellarchiv
url = "..."
sha256 = "..."

[[file]]              # je Datei, Verzeichnis oder Link, sortiert nach path
path = "/etc/veyra-release"
type = "file"         # file | dir | symlink
mode = "644"
sha256 = "..."        # nur bei file
# target = "..."      # nur bei symlink
```

## Rezept: recipe.sh

Ein Rezept ist ein Bash-Fragment in `packages/<gruppe>/<name>/recipe.sh`:

```bash
pkgname=beispiel
pkgver=1.0
pkgrel=1
pkgdesc="Kurzbeschreibung"
license=MIT
url=https://example.org
sources=(https://example.org/beispiel-1.0.tar.xz)
sha256sums=(<sha256>)
depends=(glibc)

build() {            # Arbeitsverzeichnis: $srcdir (entpackte Quellen)
  cd beispiel-1.0
  ./configure --prefix=/usr
  make
}

package() {          # alles nach $pkgdir installieren
  cd beispiel-1.0
  make DESTDIR="$pkgdir" install
}
```

`vpkg-build` lädt nichts aus dem Netz. Quellen liegen vorher im Quellverzeichnis
(`build/scripts/fetch-sources.sh`) und werden vor dem Entpacken per SHA-256 geprüft.

## Prüfen

`vpkg-verify [--pubkey PUB.pem] PAKET.vpkg` lehnt ein Paket ab, wenn

- die Signatur fehlt oder nicht passt (mit `--pubkey`),
- eine Datei nicht zum SHA-256 im Manifest passt,
- eine Datei im Archiv liegt, die nicht im Manifest steht.

`vpkg-verify` ist vorerst ein Werkzeug für den Build-Host (braucht Python 3.11+).
Auf dem Zielsystem übernimmt das später VPKG selbst.

## Noch nicht enthalten

Installieren, Entfernen, Abhängigkeitsauflösung, Konflikterkennung, Transaktionen und
Repository-Index kommen mit VPKG 0.1. VPKG 0.1 wird nicht atomar sein (siehe
docs/architecture.md).
