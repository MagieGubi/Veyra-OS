# Veyra OS

Veyra OS ist ein minimalistisches Linux-System, das vollständig aus Quellcode gebaut wird:
eigener Kernel auf Linux-Basis, eigenes Basissystem ohne fremde Distribution, eigener
Paketmanager **VPKG**, Fokus auf geringe Latenz und minimale Systemlast.

> Stand: Phase 3 (Projektstruktur und Build-Umgebung). Es gibt noch kein bootfähiges System.
> Erster Meilenstein ist **Veyra Core 0.1**: der Veyra-Kernel bootet ein selbst gebautes
> Minimalsystem in QEMU (UEFI) bis zur Textanmeldung.

## Was schon da ist

| Teil | Ort | Status |
| --- | --- | --- |
| Paketformat `.vpkg` | [docs/vpkg-format.md](docs/vpkg-format.md) | festgelegt |
| Paketbauer `vpkg-build`, Prüfer `vpkg-verify` | `build/scripts/` | getestet (`tests/vpkg/run.sh`) |
| Erstes Paket `veyra-release` | `packages/base/veyra-release/` | baut reproduzierbar |
| Gepinnte Quellen mit Signaturprüfung | `toolchain/sources.list`, `toolchain/sources.lock`, `build/scripts/fetch-sources.sh` | im CI |
| Cross-Toolchain (Stufe 2) | `toolchain/build-cross.sh`, Workflow `Toolchain` | im CI |

## Bauen

Alles wird in GitHub Actions gebaut (Reiter **Actions**, Workflow **Toolchain**).
Lokal geht es genauso mit Docker:

```bash
docker build -t veyra-bootstrap build/container
mkdir -p out
docker run --rm -v "$PWD:/repo:ro" -v "$PWD/out:/out" veyra-bootstrap /repo/build/scripts/ci-toolchain.sh
```

VPKG-Tests (brauchen `zstd`, `openssl`, `python3`):

```bash
bash tests/vpkg/run.sh
```

## Dokumentation

- [docs/architecture.md](docs/architecture.md): Architektur und Entscheidungen
- [docs/vpkg-format.md](docs/vpkg-format.md): Paket- und Rezeptformat
- [docs/build-guide.md](docs/build-guide.md): Bauablauf, Quellen und Lizenzen

## Lizenz

Eigener Code (Skripte, VPKG, Dokumentation): MIT, siehe [LICENSE](LICENSE).
Fremde Quellen behalten ihre eigenen Lizenzen, siehe [LICENSES/README.md](LICENSES/README.md).
