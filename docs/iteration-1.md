# Iterationsbericht 1: Sichere Root-Konfiguration (14.11.2026)

Auftrag: „Veyra OS – Full Operating System Development Mission“, erster konkreter Auftrag.

## Was analysiert wurde

Das ganze Repository am Code und an den CI-Logs: Build-Stufen und Workflow, Kernel-
Konfiguration, die 68 Basispakete (Rezepte, Bau-Optionen von systemd und shadow), VPKG
(alle Befehle, Prüfungen, Tests), Abbild- und ISO-Bau, Selbsttest, Dokumentation.
Ergebnis: [FULL_SYSTEM_AUDIT.md](FULL_SYSTEM_AUDIT.md), [SYSTEM_STATUS.md](SYSTEM_STATUS.md),
[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md). Die drei wichtigsten Aufgaben: sichere
Root-Konfiguration (P0-3), Versionsbedingungen in VPKG (P1-3), CLI-Installer (P3-2).

## Welche Funktionen implementiert wurden (P0-3)

- Abbild-Varianten: `VARIANTE=dev` (Entwicklungsabbild, root ohne Passwort, nur CI/VM)
  und `VARIANTE=test` (Testabbild für echte Rechner: root gesperrt, su nur für wheel).
  Variante in `/etc/veyra/variante` und `/etc/issue`.
- Paket `veyra-konten`:
  - `veyra-einrichtung`: Ersteinrichtung an Konsole 1, root-Passwort (mindestens
    8 Zeichen, zweimal, nicht gleich dem Namen) und optional ein Benutzer in `wheel`.
    Schreibt erst nach vollständiger Eingabe; ein Abbruch ändert nichts. Passwörter
    stehen nie auf der Kommandozeile.
  - `veyra-kontencheck`: prüft Rechte von passwd/group/shadow/gshadow, UID 0, leere
    Passwörter je Variante, Sperre von root während der Ersteinrichtung, SU_WHEEL_ONLY und
    für alle beschreibbare Dateien.
- Selbsttest 0.6 ruft `veyra-kontencheck` in beiden Varianten auf und prüft im Testabbild,
  dass die Ersteinrichtung an Konsole 1 wartet.
- CI: neue Testschritte im Job „VPKG-Tests“; der Abbild-Job baut und bootet zusätzlich
  das Testabbild und lädt es als `veyra-core-0.1-test` hoch.

## Welche Dateien geändert wurden

Neu: `packages/base/veyra-konten/` (Rezept, `veyra-einrichtung`, `veyra-kontencheck`),
`tests/konten/konten-test.sh`, `tests/image/variante-test.sh`, `docs/FULL_SYSTEM_AUDIT.md`,
`docs/DEVELOPMENT_PLAN.md`, `docs/SYSTEM_STATUS.md`, `docs/iteration-1.md`.
Geändert: `image/build-image.sh`, `packages/test/veyra-selftest/recipe.sh`,
`.github/workflows/toolchain.yml`, `tests/vpkg/vpkg-test.sh` (Testtext), `ROADMAP.md`
(P0-3, neu P1-8), `README.md`, `docs/hardware-test.md`.

## Welche Tests ausgeführt wurden und mit welchem Ergebnis

Lokal (Ubuntu 24.04 wie der CI-Runner):

| Test | Ergebnis |
| --- | --- |
| `tests/konten/konten-test.sh` (als root) | 17 von 17 bestanden |
| `tests/image/variante-test.sh` (als root, Probe-System statt Stufe 4b) | 4 von 4 bestanden |
| `tests/vpkg/vpkg-test.sh` (als root) | 24 von 24 bestanden (Test 19 läuft nur ohne root) |
| `tests/vpkg/run.sh` | 6 von 6 bestanden |
| `tests/boot/diagnose-test.sh` | 9 von 9 bestanden |
| shellcheck über alle Skripte, Rezept-Syntax, `check-pinned.sh` | sauber, 0 offene Quellen |
| Bau des Pakets `veyra-konten` mit `vpkg-build` und Manifestprüfung | ok |

Nicht ausgeführt: Bau und Boot des echten Testabbilds (braucht Stufe 4b aus dem CI und
QEMU; läuft erst nach einem Push im CI). Die Ersteinrichtung mit Eingaben an Konsole 1
läuft im CI nicht, weil QEMU dort ohne Bildschirm startet. Nichts auf echter Hardware.

## Welche Probleme noch offen sind

- CI-Nachweis für P0-3 fehlt, bis Adrian den Push erlaubt.
- Kein PAM und kein sudo (neue Aufgabe P1-8); Hashes SHA-512-crypt statt yescrypt.
- Die Live-ISO bleibt ohne root-Passwort (Live-System).
- Die Prüfung auf für alle beschreibbare Dateien lief noch nie gegen das echte
  Basissystem; findet sie dort etwas, wird der CI-Lauf rot und der Fund behoben.

## Was als Nächstes umgesetzt wird

P1-3: Versionsbedingungen in VPKG (`name>=ver`, `name=ver`, `name<ver`) mit Tests,
danach P3-2: CLI-Installer auf eine virtuelle Platte.
