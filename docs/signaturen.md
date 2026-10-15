# Paketsignaturen

Veyra signiert jedes Paket mit einem Ed25519-Schlüssel. Die Signatur liegt als
`PAKET.vpkg.sig` neben dem Paket und gilt für die ganze `.vpkg`-Datei. Seit VPKG 0.3 ist
auch der Repository-Index signiert (`index.toml.sig`, siehe [vpkg.md](vpkg.md#repository)).

| Teil | Ort |
| --- | --- |
| Öffentlicher Schlüssel | `packages/base/veyra-keyring/veyra-2026.pem`, im System `/etc/vpkg/keys/veyra-2026.pem` (Paket `veyra-keyring`) |
| Privater Schlüssel | nur als GitHub-Secret `VPKG_SIGNING_KEY` (Repository-Einstellungen, Secrets and variables, Actions), nie im Repository |
| Signieren | `build/scripts/sign-packages.sh` (Pakete und `index.toml`), im CI im Job „Abbild und Boot-Test“: Pakete vor dem Bau des Abbilds, der Index beim Zusammenstellen des Repositories |
| Prüfen | `vpkg` (Pflicht, sobald ein Schlüssel in `/etc/vpkg/keys` liegt), `vpkg-verify --pubkey` |

Ablauf im CI: Ist das Secret gesetzt, prüft `sign-packages.sh` zuerst, dass der private
Schlüssel zum öffentlichen im Repository passt, und signiert dann alle Basis- und
Zusatzpakete. Das Abbild installiert `veyra-keyring` als erstes Paket; ab dann lehnt VPKG
jedes unsignierte oder falsch signierte Paket ab, auch beim Eintragen der Basispakete.
Der Selbsttest im gebooteten System prüft, dass ein unsigniertes Paket abgelehnt wird.

Fehlt das Secret, baut das CI weiter, aber ohne Signaturen und ohne `veyra-keyring`
(Warnung im Lauf).

Schlüssel erzeugen oder wechseln (zum Beispiel in Git Bash):

```bash
openssl genpkey -algorithm ed25519 -out veyra-signing-key.pem
openssl pkey -in veyra-signing-key.pem -pubout
```

Den Inhalt von `veyra-signing-key.pem` als Secret `VPKG_SIGNING_KEY` eintragen, den
ausgegebenen öffentlichen Schlüssel als `packages/base/veyra-keyring/veyra-2026.pem`
ins Repository legen (und `sha256sums` im Rezept anpassen).

Aktueller Schlüssel (seit 13.10.2026, von Adrian erzeugt): `veyra-2026.pem`,
SHA-256 des öffentlichen Schlüssels (DER):
`dae1e539857c6f7883263767a829b4e4696298697e4cec642d2a48004569f152`
