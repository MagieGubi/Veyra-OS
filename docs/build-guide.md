# Bauanleitung

## Voraussetzungen

- Docker oder Podman (der gesamte Bootstrap läuft im Container `build/container/Dockerfile`)
- Für die VPKG-Tests: `zstd`, `openssl` (3.x), `python3` (3.11+)
- Etwa 15 GB freier Platz für die Cross-Toolchain

## Ablauf

1. **Quellen holen und prüfen** (`build/scripts/fetch-sources.sh`): lädt jede Quelle aus
   `toolchain/sources.list`. Steht sie in `toolchain/sources.lock`, muss der SHA-256 passen.
   Neue Quellen werden nur nach gültiger GPG-Signatur aufgenommen (GNU-Keyring bzw. die
   Kernel-Schlüssel von Linus Torvalds und Greg Kroah-Hartman per WKD).
2. **Cross-Toolchain** (`toolchain/build-cross.sh`, als normaler Nutzer): Ergebnis in
   `/veyra/tools` und `/veyra/usr`. Das Skript prüft am Ende, dass Programme gegen die
   Veyra-glibc gelinkt werden (`/lib64/ld-linux-x86-64.so.2`) und C++ funktioniert.
3. **Temporäre Werkzeuge** (`temptools/build-temp.sh`, als normaler Nutzer): m4, ncurses,
   bash, coreutils, diffutils, file, findutils, gawk, grep, gzip, make, patch, sed, tar, xz,
   binutils und GCC (jeweils Durchlauf 2), mit der Cross-Toolchain für das Zielsystem gebaut.
   Am Ende prüft das Skript, dass die Programme den Veyra-Programm-Interpreter nutzen.
   Quellen ohne prüfbare Signatur (file, xz) werden vor dem Festlegen gegen die
   MD5-Summen aus dem Buch Linux From Scratch 12.4 geprüft.
4. Weitere Stufen (chroot-Bau, Image) folgen in Phase 4 und 5.

Im Container: `build/scripts/ci-toolchain.sh` (Stufe 2) und `build/scripts/ci-temptools.sh` (Stufe 3); so läuft es auch in GitHub Actions.

## Gepinnte Versionen (Stufe 2)

Siehe `toolchain/versions.sh`: binutils 2.45, GCC 15.2.0, glibc 2.42, GMP 6.3.0,
MPFR 4.2.2, MPC 1.3.1 (Kombination aus Linux From Scratch 12.4) und Linux-Header 6.18.

## Zurücksetzen

Jeder Schritt ist ein eigener Git-Commit; `git revert <commit>` macht ihn rückgängig.
Build-Ergebnisse liegen nur in `out/` bzw. im Container und werden nicht eingecheckt.
