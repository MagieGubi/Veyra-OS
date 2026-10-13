# VPKG 0.1: Bedienung

`vpkg` ist die Paketverwaltung von Veyra OS (`packages/base/vpkg/vpkg`, Python 3.11+,
nur Standardbibliothek, dazu `zstd`, `tar` und `openssl`). Sie installiert, aktualisiert
und entfernt `.vpkg`-Pakete ([Format](vpkg-format.md)), löst Abhängigkeiten auf und
weiß zu jeder Datei, zu welchem Paket sie gehört.

| Befehl | Was er tut |
| --- | --- |
| `vpkg install PAKET...` | `.vpkg`-Dateien oder Namen aus dem Repository installieren; fehlende Abhängigkeiten kommen aus dem Repository dazu. Ist ein Paket schon installiert, wird es aktualisiert (alte Dateien, die in der neuen Version fehlen, werden entfernt). |
| `vpkg upgrade` | Alle installierten Pakete, für die das Repository eine neuere Version hat, aktualisieren. |
| `vpkg remove NAME...` | Pakete entfernen. Abgelehnt, solange ein anderes Paket sie braucht. |
| `vpkg list` | Installierte Pakete mit Version. |
| `vpkg info NAME` | Beschreibung, Abhängigkeiten, wer das Paket braucht. |
| `vpkg files NAME` | Dateien eines Pakets. |
| `vpkg owner PFAD` | Zu welchem Paket eine Datei gehört. |
| `vpkg check [NAME...]` | Installierte Dateien gegen die Prüfsummen prüfen, fehlende Abhängigkeiten melden. |
| `vpkg register PAKET...` | Pakete eintragen, deren Dateien schon im System liegen (Bau des Basissystems). |
| `vpkg index VERZ` | `index.toml` für ein Repository-Verzeichnis schreiben. |

Alle Befehle verstehen `--root DIR`, um ein anderes System zu bearbeiten (so baut
`image/build-image.sh` das Abbild).

## Sicherheit

- Jede Datei eines Pakets wird vor dem Installieren gegen ihren SHA-256 im Manifest
  geprüft, ebenso das Install-Skript. Pakete aus einem Repository müssen außerdem zum
  SHA-256 im `index.toml` passen.
- Liegen öffentliche Schlüssel in `/etc/vpkg/keys/*.pem`, muss jedes Paket eine gültige
  Ed25519-Signatur (`PAKET.vpkg.sig`) haben. Ohne Schlüssel werden Signaturen nicht
  geprüft. Den Veyra-Schlüssel bringt das Paket `veyra-keyring` mit (siehe
  [signaturen.md](signaturen.md)).
- Dateien, die einem anderen Paket gehören oder keinem Paket gehören, werden nicht
  überschrieben (außer mit `--overwrite`).

## Konfigurationsdateien

Dateien unter `/etc`, die seit der Installation geändert wurden, bleiben erhalten:
beim Aktualisieren kommt die neue Fassung als `DATEI.vpkgnew` daneben, beim Entfernen
bleibt die geänderte Datei als `DATEI.vpkgsave`.

## Repository

Ein Repository ist ein Verzeichnis (oder eine http(s)-Adresse) mit `.vpkg`-Dateien,
den zugehörigen `.sig`-Dateien und einem `index.toml` von `vpkg index`. Die Quelle steht
in `/etc/vpkg/repo` oder wird mit `--repo` angegeben. Das CI stellt bei jedem Lauf ein
Repository mit allen Paketen als Artefakt `veyra-repo` bereit; öffentlich gehostet ist
es noch nicht.

## Datenbank

`/var/lib/vpkg/installed/NAME/manifest.toml` (und `install`, falls vorhanden) je
installiertem Paket. `/var/lib/vpkg/lock` verhindert zwei gleichzeitige Vorgänge.

## Grenzen von 0.1

- Nicht atomar: bricht ein Vorgang mitten ab, kann ein halbfertiger Zustand bleiben.
  `vpkg check` zeigt ihn, eine Neuinstallation des Pakets repariert ihn.
- Keine Versionsbedingungen in Abhängigkeiten (nur Namen), kein `pre_remove`.
- Kernel und Kernelmodule sind noch kein Paket.
