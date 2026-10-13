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
| Cross-Toolchain (Stufe 2) | `toolchain/build-cross.sh`, Workflow `Toolchain` | im CI gebaut (GCC 15.2.0, glibc 2.42) |
| Temporäre Werkzeuge (Stufe 3) | `temptools/build-temp.sh`, Workflow `Toolchain` | im CI gebaut |
| Veyra-Kernel 6.18.56-veyra1 (Phase 4) | `kernel/`, Jobs `kernel` und `kernel-reproducible` | im CI gebaut, zwei Builds bit-identisch (bzImage `7fac3305…`) |
| Basissystem in chroot, Stufe 4a (gettext, bison, perl, Python, texinfo, util-linux) | `stage4/`, Job `stage4a` | im CI gebaut |
| Basispakete als `.vpkg`, Stufe 4b (68 Pakete, glibc bis systemd) | `packages/core/`, `stage4/order-*.list` | Teil 1 und 2 im CI gebaut, Teil 3 im CI |
| Abbild und Boot-Test in QEMU (Phase 5) | `image/`, Job `image` | im CI |

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
