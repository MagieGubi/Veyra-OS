# VPKG 0.3: Bedienung

`vpkg` ist die Paketverwaltung von Veyra OS (`packages/base/vpkg/vpkg`, Python 3.11+,
nur Standardbibliothek, dazu `zstd`, `tar` und `openssl`). Sie installiert, aktualisiert
und entfernt `.vpkg`-Pakete ([Format](vpkg-format.md)), löst Abhängigkeiten auf und
weiß zu jeder Datei, zu welchem Paket sie gehört.

| Befehl | Was er tut |
| --- | --- |
| `vpkg install PAKET...` | `.vpkg`-Dateien oder Namen aus dem Repository installieren; fehlende Abhängigkeiten kommen aus dem Repository dazu. Ist ein Paket schon installiert, wird es aktualisiert (alte Dateien, die in der neuen Version fehlen, werden entfernt). Eine ältere Version als die installierte nur mit `--allow-downgrade`. |
| `vpkg upgrade` | Alle installierten Pakete, für die das Repository eine neuere Version hat, aktualisieren. |
| `vpkg remove NAME...` | Pakete entfernen. Abgelehnt, solange ein anderes Paket sie braucht. |
| `vpkg list` | Installierte Pakete mit Version. |
| `vpkg info NAME` | Beschreibung, Abhängigkeiten, wer das Paket braucht. |
| `vpkg files NAME` | Dateien eines Pakets. |
| `vpkg owner PFAD` | Zu welchem Paket eine Datei gehört. |
| `vpkg check [NAME...]` | Installierte Dateien gegen die Prüfsummen prüfen, fehlende Abhängigkeiten melden. |
| `vpkg recover` | Einen unterbrochenen Vorgang (Absturz, Stromausfall) zurücknehmen. Passiert auch automatisch beim nächsten schreibenden Befehl. |
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
- Das Manifest wird vor jeder Änderung vollständig geprüft: Versionsangaben, Namen in
  `depends`/`provides`/`conflicts`, Dateityp, Rechte (oktal, höchstens 4 Stellen),
  Prüfsummen (64 Hex-Zeichen), Link-Ziele. Abgelehnt werden außerdem doppelte Pfade,
  Pfade mit `..` oder Nullbyte, Pfade unter `/var/lib/vpkg` und Einträge unterhalb einer
  Datei oder eines Links.
- Fehler beim Schreiben (volle Platte, fehlende Rechte) enden mit einer Meldung
  `vpkg: ...`, nicht mit einem Python-Traceback.

## Transaktionen

`install`, `upgrade`, `remove` und `register` laufen als Transaktion: Entweder ist der
ganze Vorgang ausgeführt, oder das System ist danach unverändert.

- Jede Änderung (Datei anlegen oder ersetzen, Verzeichnis anlegen oder löschen, Datei
  löschen oder umbenennen, Datenbankeintrag ändern) wird **vorher** in
  `/var/lib/vpkg/txn/journal` protokolliert (eine JSON-Zeile, mit `fsync`). Ersetzte und
  gelöschte Dateien bleiben bis zum Abschluss in `/var/lib/vpkg/txn/sicherung/`
  (fester Link, sonst Kopie mit Besitzer und Rechten).
- Neue Dateien werden erst als `.vpkg-PID-NAME` geschrieben und dann mit `rename`
  an ihren Platz gesetzt; eine Datei ist also nie halb geschrieben.
- Abschluss: das Journal wird gelöscht, danach die Sicherungen.
- Scheitert eine Änderung, nimmt VPKG alle bisherigen in umgekehrter Reihenfolge zurück
  und meldet `... abgebrochen (GRUND); N Aenderung(en) zurueckgenommen, das System ist
  unveraendert`.
- Bricht VPKG selbst ab (Absturz, Stromausfall), bleibt das Journal liegen. `vpkg check`
  meldet das, `vpkg recover` oder der nächste schreibende Befehl nimmt den Vorgang
  zurück. Lässt sich etwas nicht zurücknehmen, bleibt das Journal stehen und VPKG nennt
  die betroffenen Pfade.
- Nicht zurücknehmbar sind Install-Skripte (`post_install`): sie laufen erst nach dem
  Abschluss. Scheitert eins, sind die Pakete installiert und VPKG sagt das.

Für Tests gibt es `VPKG_TEST_ABBRUCH=fehler:N` (die Änderung nach der N-ten scheitert)
und `VPKG_TEST_ABBRUCH=absturz:N` (VPKG beendet sich dort sofort, Rückgabewert 70).

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

Ab VPKG 0.3 ist auch der Index geschützt (Aufbau: [vpkg-format.md](vpkg-format.md#repository-index)):

- Liegen Schlüssel in `/etc/vpkg/keys`, muss `index.toml.sig` eine gültige Ed25519-Signatur
  des Index sein. Ein unsignierter oder veränderter Index wird abgelehnt.
- Jeder Index trägt einen **Stand** (`stand = ZAHL`, im CI die Commit-Zeit). VPKG merkt sich
  in `/var/lib/vpkg/repo-stand.json` je Quelle den höchsten signierten Stand und lehnt
  einen älteren ab. So kann ein Spiegel keine alte Kopie mit bekannt fehlerhaften Paketen
  als aktuell ausgeben. Ein signierter Index ohne Stand wird abgelehnt.
- Jeder Eintrag wird geprüft: Paketname, Dateiname (nur ein Name, kein Pfad), Prüfsumme,
  Version, Abhängigkeiten. Das geladene Paket muss genau dem Eintrag entsprechen (Name,
  Version, Abhängigkeiten), sonst wird es abgelehnt, auch wenn es selbst gültig signiert ist.
- Das Repository wird erst geladen, wenn es gebraucht wird (Paketname oder fehlende
  Abhängigkeit). Eine lokale Paketdatei installiert sich auch ohne erreichbares Repository.

## Datenbank

`/var/lib/vpkg/installed/NAME/manifest.toml` (und `install`, falls vorhanden) je
installiertem Paket. `/var/lib/vpkg/lock` verhindert zwei gleichzeitige Vorgänge,
`/var/lib/vpkg/txn/` gibt es nur während eines Vorgangs (siehe Transaktionen),
`/var/lib/vpkg/repo-stand.json` hält den zuletzt angenommenen Index-Stand je Quelle.

## Grenzen von 0.3

- Install-Skripte lassen sich nicht zurücknehmen (siehe oben).
- Die Transaktion schützt vor Abbrüchen, nicht vor Fremdeingriffen: wer während eines
  Vorgangs selbst Dateien im System ändert, kann die Rücknahme stören (VPKG meldet das).
- Der Index hat kein Ablaufdatum: ein Spiegel kann neue Stände zurückhalten (alte, aber
  nicht ältere als die schon gesehenen ausliefern). Ein Ablaufdatum braucht eine
  verlässliche Uhrzeit im System und folgt später.
- Ohne Schlüssel in `/etc/vpkg/keys` wird weder Index noch Paket auf Signaturen geprüft.
- Keine Versionsbedingungen in Abhängigkeiten (nur Namen), kein `pre_remove`.
- Kernel und Kernelmodule sind noch kein Paket.
