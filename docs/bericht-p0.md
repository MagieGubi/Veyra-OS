# Bericht: VPKG 0.3 und Netzwerk-Absicherung (15.10.2026)

Auftrag: „Veyra OS – Next Development Phase“. Bestandsaufnahme, ROADMAP.md mit P0 bis P4,
dann die wertvollste Aufgabe umsetzen und testen, danach die nächste unabhängige.

## 1. Ausgangszustand

- Toolchain, Kernel (bit-identisch reproduzierbar) und 68 Basispakete werden im CI aus
  gepinnten, geprüften Quellen gebaut; Abbild und Live-ISO booten in QEMU per UEFI.
- VPKG 0.2: Pakete Ed25519-signiert, Transaktionen mit Rücknahme, strenge Manifestprüfung.
- **Lücken:** Der Repository-Index war unsigniert und ungeprüft. Ein Spiegel hätte alte,
  gültig signierte Pakete als aktuell ausgeben, ein anderes Paket hinter einem Namen
  ausliefern oder eine ältere Version einspielen können; der Dateiname aus dem Index wurde
  ungeprüft als Pfad benutzt. Außerdem antwortete systemd-resolved per LLMNR (Port 5355)
  im lokalen Netz, und kein Test prüfte offene Ports.

## 2. Implementierte Änderungen

- **VPKG 0.3 (P0-1):** `index.toml.sig` ist Pflicht, sobald Schlüssel eingerichtet sind;
  neues Index-Feld `stand`, VPKG merkt sich je Quelle den höchsten signierten Stand
  (`/var/lib/vpkg/repo-stand.json`) und lehnt ältere Indizes ab; Index-Einträge werden
  streng geprüft (Name, Dateiname ohne Pfad, Prüfsumme, Version); ein geladenes Paket muss
  zum Index-Eintrag passen; ältere Versionen nur mit `--allow-downgrade`. Der Index wird
  erst geladen, wenn er gebraucht wird, damit lokale Installationen nicht blockiert werden.
- **CI:** signiert jetzt auch den Index (mit dem Secret `VPKG_SIGNING_KEY`, Schlüssel nur
  kurz in einer Datei mit Rechten 600) und installiert zur Gegenprobe ein Paket daraus.
- **Keine offenen Ports (P0-2):** LLMNR und mDNS in systemd-resolved aus; der Selbsttest
  prüft mit `ss`, dass außer Loopback und den DHCP-Antwort-Ports nichts lauscht.
- **ROADMAP.md** mit P0 bis P4, je Aufgabe Ziel, Dateien, Schritte, Risiken, Akzeptanz und
  Nachweis.

## 3. Neue und geänderte Dateien

Neu: `ROADMAP.md`, `docs/bericht-p0.md`. Geändert: `packages/base/vpkg/vpkg`,
`packages/base/vpkg/recipe.sh`, `build/scripts/sign-packages.sh`,
`.github/workflows/toolchain.yml`, `packages/base/veyra-netzwerk/recipe.sh`,
`packages/test/veyra-selftest/recipe.sh`, `tests/vpkg/vpkg-test.sh`, `docs/vpkg.md`,
`docs/vpkg-format.md`, `docs/signaturen.md`, `docs/architecture.md`, `docs/phase6.md`,
`README.md`.

## 4. Builds und Tests mit echten Ergebnissen

CI-Lauf [38697548625](https://github.com/MagieGubi/Veyra-OS/actions/runs/38697548625),
alle 12 Jobs grün. Auszüge aus den Logs:

- VPKG-Tests: „Alle 25 VPKG-Tests bestanden.“ (darunter Tests 21 bis 24 für Index-Signatur,
  alten oder fehlenden Stand, falsche Einträge und Downgrade).
- Repository: „sign-packages: 74 Datei(en) signiert“, „Pakete: 73, signiert: 73, Index
  signiert: ja“, Gegenprobe-Installation von veyra-release erfolgreich.
- Selbsttest im Abbild und in der Live-ISO: „Offene Ports: ok (nur Loopback)“,
  „Signaturpruefung: ok“, „Netzwerk: ok (enp0s2 10.0.2.15/24 per DHCP …)“,
  „Dienste: ok“, „VEYRA-SELBSTTEST: OK“.
- Login nach 7,2 s (Abbild) und 6,4 s (Live-ISO), sauber heruntergefahren in 1,4 s und
  1,0 s.
- Lokal (ohne root): ebenfalls 25 von 25 VPKG-Tests, shellcheck sauber.

## 5. Offene Fehler und Risiken

- Kein Ablaufdatum im Index: ein Spiegel kann neue Stände zurückhalten (Freeze-Angriff).
- Wer den Index zuvor schon signiert hatte, braucht nach dem Update einmal `vpkg index`,
  weil ein signierter Index ohne `stand` abgelehnt wird.
- Root ohne Passwort in allen Abbildern (P0-3, offen).
- Keine Firewall; der Port-Test prüft nur den Zustand nach dem Start.

## 6. Nicht ausführbare Tests

- **Echte Hardware und VirtualBox:** in der Cloud nicht möglich; alle Ergebnisse stammen
  aus QEMU mit KVM.
- **Online-Repository über das Netz:** es gibt noch keinen Server (P3-1); getestet wurde
  mit einem lokalen Repository-Verzeichnis.

## 7. Drei nächste empfohlene Aufgaben

1. **P0-3:** Abbild-Variante ohne passwortloses root (vor jedem Test auf echter Hardware).
2. **P1-3:** Versionsbedingungen in Abhängigkeiten (`glibc>=2.42`), damit Updates in der
   richtigen Reihenfolge laufen.
3. **P1-4:** Pakete und Abbild reproduzierbar machen und im CI doppelt bauen und vergleichen.

## 8. Lokal testen

VPKG-Tests (Linux oder WSL, braucht python3 3.11+, zstd, openssl, kein root):

```
git clone https://github.com/MagieGubi/Veyra-OS.git
cd Veyra-OS
bash tests/vpkg/vpkg-test.sh
```

Erwartet: „Alle 25 VPKG-Tests bestanden.“ (als root wird Test 19 übersprungen).

System in VirtualBox: Artefakt `veyra-live-iso` aus dem CI-Lauf oben herunterladen
(GitHub-Anmeldung nötig), ZIP entpacken und nach [virtualbox.md](virtualbox.md) starten.
Nach dem Login als root zeigt `journalctl -u veyra-selftest` den Selbsttest, darin die
Zeile „Offene Ports“.
