# Paketsignaturen

Veyra signiert jedes Paket mit einem Ed25519-Schlüssel. Die Signatur liegt als
`PAKET.vpkg.sig` neben dem Paket und gilt für die ganze `.vpkg`-Datei.

| Teil | Ort |
| --- | --- |
| Öffentlicher Schlüssel | `packages/base/veyra-keyring/veyra-2026.pem`, im System `/etc/vpkg/keys/veyra-2026.pem` (Paket `veyra-keyring`) |
| Privater Schlüssel | nur als GitHub-Secret `VPKG_SIGNING_KEY` (Repository-Einstellungen, Secrets and variables, Actions), nie im Repository |
| Signieren | `build/scripts/sign-packages.sh`, im CI im Job „Abbild und Boot-Test“ |
| Prüfen | `vpkg` (Pflicht, sobald ein Schlüssel in `/etc/vpkg/keys` liegt), `vpkg-verify --pubkey` |

Ablauf im CI: Ist das Secret gesetzt, prüft `sign-packages.sh` zuerst, dass der private
Schlüssel zum öffentlichen im Repository passt, und signiert dann alle Basis- und
Zusatzpakete. Das Abbild installiert `veyra-keyring` als erstes Paket; ab dann lehnt VPKG
jedes unsignierte oder falsch signierte Paket ab, auch beim Eintragen der Basispakete.
Der Selbsttest im gebooteten System prüft, dass ein unsigniertes Paket abgelehnt wird.

Fehlt das Secret, baut das CI weiter, aber ohne Signaturen und ohne `veyra-keyring`
(Warnung im Lauf).

Schlüsselwechsel: neuen Schlüssel erzeugen
(`openssl genpkey -algorithm ed25519 -out neu.pem`), den öffentlichen Teil als neue Datei
ins Paket `veyra-keyring` legen, Secret ersetzen. Fingerabdruck des aktuellen Schlüssels
(SHA-256 des öffentlichen Schlüssels im DER-Format):
`00399a7e3e815ea41eb29f3faa282d84eccb42ebf68c71a78225e001159ca135`.
