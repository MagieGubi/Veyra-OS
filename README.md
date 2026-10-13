# Veyra OS

Veyra OS ist ein minimalistisches Linux-System, das vollständig aus Quellcode gebaut wird:
eigener Kernel auf Linux-Basis, eigenes Basissystem ohne fremde Distribution, eigener
Paketmanager **VPKG**, Fokus auf geringe Latenz und minimale Systemlast.

> Stand: **Veyra Core 0.1** bootet, mit **VPKG 0.1**. Der Veyra-Kernel startet das selbst
> gebaute Basissystem in QEMU direkt per UEFI bis zur Textanmeldung; im laufenden System
> prüft VPKG alle 71 Pakete und installiert und entfernt ein Testpaket (CI-Lauf 38367370470).

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
| Basispakete als `.vpkg`, Stufe 4b (68 Pakete, glibc bis systemd) | `packages/core/`, `stage4/order-*.list` | im CI gebaut |
| Paketverwaltung VPKG 0.1 (installieren, entfernen, Abhängigkeiten) | `packages/base/vpkg/`, [docs/vpkg.md](docs/vpkg.md) | 14 Tests grün, Selbsttest im gebooteten Abbild bestanden |
| Paketsignaturen (Ed25519), Paket-Repository als CI-Artefakt | `packages/base/veyra-keyring/`, [docs/signaturen.md](docs/signaturen.md) | eingebaut; signiert wird, sobald das Secret `VPKG_SIGNING_KEY` gesetzt ist |
| Abbild und Boot-Test in QEMU (Phase 5) | `image/`, Job `image` | bootet bis zum Login (UEFI, ohne Bootloader, 6,4 s ab QEMU-Start mit KVM, [Messwerte](docs/messwerte.md)) |

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
- [docs/vpkg.md](docs/vpkg.md): Bedienung von VPKG 0.1
- [docs/signaturen.md](docs/signaturen.md): Paketsignaturen
- [docs/messwerte.md](docs/messwerte.md): Bootzeit und Ressourcen (VM)
- [docs/build-guide.md](docs/build-guide.md): Bauablauf, Quellen und Lizenzen

## Lizenz

Eigener Code (Skripte, VPKG, Dokumentation): MIT, siehe [LICENSE](LICENSE).
Fremde Quellen behalten ihre eigenen Lizenzen, siehe [LICENSES/README.md](LICENSES/README.md).
