# VPKG-Paketformat (Version 1)

Stand: Core 0.1. Dieses Format erzeugt `vpkg-build` schon heute; das spätere VPKG 0.1
(Installieren, Entfernen, Abhängigkeiten) liest genau dieses Format.

## Paketdatei

`NAME-VERSION-RELEASE-ARCH.vpkg` ist ein mit zstd komprimiertes POSIX-tar-Archiv:

```
manifest.toml     Metadaten und Dateiliste
files/            Dateien, so wie sie ab / installiert werden
install           nur wenn das Rezept post_install() oder pre_remove() hat (siehe unten)
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
depends = []          # Laufzeitabhängigkeiten: Name, ab VPKG 0.4 optional mit Bedingung (glibc>=2.42)
makedepends = []      # Build-Abhängigkeiten
conflicts = []
provides = []
recipe_sha256 = "..." # Hash von recipe.sh = Herkunftsnachweis
build_date = 0        # SOURCE_DATE_EPOCH
install_sha256 = "..." # nur mit Install-Skript: SHA-256 der Datei install

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

`usr/share/info/dir` wird nie mit verpackt: install-info schreibt die Datei in jedem
Paket neu, sie würde sonst zwischen Paketen kollidieren.

## Optionale Funktion post_install()

Ein Rezept darf `post_install()` definieren. Sie läuft nach dem Auspacken im Zielsystem,
für Schritte, die den Zustand des Systems ändern und keiner Datei im Paket entsprechen
(zum Beispiel Locales erzeugen oder `pwconv`). `vpkg-build` legt sie als Datei `install`
ins Paket (Variablen `pkgname`, `pkgver`, `pkgrel` plus die Funktion) und trägt ihren
SHA-256 als `install_sha256` ins Manifest ein; `vpkg-verify` und VPKG lehnen ein Paket ab,
dessen Skript nicht dazu passt. VPKG führt sie nach dem Installieren aus, bei `--root` per
`chroot`. Beim Bau des Basissystems ruft `stage4/chroot/30-packages.sh` sie direkt auf.

Scheitert `post_install`, bleibt das Paket installiert (die Dateien liegen schon, ein Skript
lässt sich nicht zurücknehmen). VPKG legt dann im Datenbankeintrag die Datei
`skript-fehler` an; `vpkg check` meldet das Paket als fehlerhaft, bis
`vpkg rerun-script PAKET` gelingt (ab VPKG 0.5).

## Optionale Funktion pre_remove() (ab VPKG 0.5)

`pre_remove()` läuft vor dem Entfernen im Zielsystem, z. B. um einen Dienst zu stoppen.
Sie steht in derselben Datei `install` wie `post_install` (geprüft über
`install_sha256`). Scheitert sie, entfernt VPKG nichts; `vpkg remove --no-scripts`
entfernt ohne Skript. Bei einer Aktualisierung läuft `pre_remove` nicht.

## Repository-Index

`vpkg index [--stand ZAHL] VERZ` schreibt `VERZ/index.toml`:

```toml
format = 1
stand = 1792000000        # muss mit jeder Ausgabe steigen (CI: Commit-Zeit)

[[package]]
name = "liba"
version = "1.0"
release = 1
description = ""
depends = []
provides = []
conflicts = []
filename = "liba-1.0-1-x86_64.vpkg"   # nur ein Dateiname, kein Pfad
sha256 = "…"                          # SHA-256 der .vpkg-Datei
```

`stand` ist neu in VPKG 0.3. Ohne `--stand` gilt `SOURCE_DATE_EPOCH`, sonst die aktuelle
Zeit. Ältere Indizes ohne `stand` liest VPKG weiter, solange keine Schlüssel eingerichtet
sind; ein **signierter** Index muss `stand` enthalten. Die Signatur `index.toml.sig`
(Ed25519 über die ganze Datei) schreibt `build/scripts/sign-packages.sh`.
Migration bestehender Repositories: `vpkg index` neu laufen lassen und signieren.

## Installieren: VPKG

Die Bedienung von `vpkg` steht in [vpkg.md](vpkg.md).

## Basissystem (Stufe 4b)

Die Pakete in `packages/core/` werden im Zielsystem selbst gebaut, in der Reihenfolge von
`stage4/order-N.list`, und jedes wird sofort installiert. Weil es dort anfangs noch kein zstd
gibt, schreibt `vpkg-build --no-compress` das unkomprimierte tar; außerhalb wird es mit
`zstd -19 -T1` zur `.vpkg`-Datei (bit-gleich mit dem direkten Weg, siehe Test 5).
Leere `sha256sums` werden mit `--lock` aus den gepinnten Quellen ergänzt.

## Versionsbedingungen (ab VPKG 0.4)

`depends` darf Einträge der Form `name`, `name>=ver`, `name<=ver`, `name=ver`, `name<ver`
oder `name>ver` enthalten; `ver` mit `-` vergleicht Version und Release. `provides` und
`conflicts` bleiben reine Namen. Das Paketformat bleibt `format = 1`.

**Migration:** VPKG bis 0.3 lehnt Pakete und Repository-Indizes mit Bedingungen als
„ungültige Liste 'depends'“ ab. Deshalb zuerst `vpkg` 0.4 installieren, danach Pakete
mit Bedingungen. Bisher nutzt kein Veyra-Paket Bedingungen; sie kommen erst mit den
ersten Paketen, die sie brauchen.

## Gruppen (ab VPKG 0.6)

Manifest und Index-Eintrag dürfen eine Liste `groups = ["veyra-security"]` enthalten
(Namen wie Paketnamen). `vpkg-build` schreibt das Feld nur, wenn das Rezept `groups=(...)`
setzt; Pakete ohne Gruppe bleiben bit-gleich zu vorher. Das Paketformat bleibt
`format = 1`, weil das Feld optional ist: VPKG bis 0.5 liest es nicht und installiert
solche Pakete trotzdem richtig (nur ohne `@gruppe`). Metapakete sind gewöhnliche Pakete
ohne Dateien (`package() { :; }`), die ihre Gruppe über `depends` nachziehen.
