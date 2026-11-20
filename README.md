# Veyra OS (mit n.tomiska)

Veyra OS ist ein minimalistisches Linux-System, das vollständig aus Quellcode gebaut wird:
eigener Kernel auf Linux-Basis, eigenes Basissystem ohne fremde Distribution, eigener
Paketmanager **VPKG**, Fokus auf geringe Latenz und minimale Systemlast.

> Stand: **Veyra OS 0.6.0**. Neu gegenüber 0.5: Firewall und Kernel-Härtung, VPKG 0.6 mit
> Spiegeln, Cache und Metapaketen, systemd-boot mit automatischem Rückfall auf den alten
> Kernel, `veyra-recovery` in der Live-ISO, WLAN-Software (iwd) und ein experimenteller
> Desktop (cage mit kitty unter Wayland). Alles in QEMU im CI nachgewiesen
> ([Lauf 44731627264](https://github.com/MagieGubi/Veyra-OS/actions/runs/44731627264)), **nie auf echter Hardware**.
> Release-Notizen: [docs/release-0.6.md](docs/release-0.6.md), Desktop: [docs/desktop.md](docs/desktop.md).

## Was schon da ist

| Teil | Ort | Status |
| --- | --- | --- |
| Paketformat `.vpkg` | [docs/vpkg-format.md](docs/vpkg-format.md) | festgelegt |
| Paketbauer `vpkg-build`, Prüfer `vpkg-verify` | `build/scripts/` | getestet (`tests/vpkg/run.sh`) |
| Erstes Paket `veyra-release` | `packages/base/veyra-release/` | baut reproduzierbar |
| Gepinnte Quellen mit Signaturprüfung | `toolchain/sources.list`, `toolchain/sources.lock`, `build/scripts/fetch-sources.sh` | im CI |
| Cross-Toolchain (Stufe 2) | `toolchain/build-cross.sh`, Workflow `Toolchain` | im CI gebaut (GCC 15.2.0, glibc 2.42) |
| Temporäre Werkzeuge (Stufe 3) | `temptools/build-temp.sh`, Workflow `Toolchain` | im CI gebaut |
| Veyra-Kernel 6.18.56-veyra2 (Phase 4, ab veyra2 mit Laptop-Treibern) | `kernel/`, Jobs `kernel` und `kernel-reproducible` | im CI gebaut, zwei Builds bit-identisch |
| Basissystem in chroot, Stufe 4a (gettext, bison, perl, Python, texinfo, util-linux) | `stage4/`, Job `stage4a` | im CI gebaut |
| Basispakete als `.vpkg`, Stufe 4b (68 Pakete, glibc bis systemd) | `packages/core/`, `stage4/order-*.list` | im CI gebaut |
| Paketverwaltung VPKG 0.5 (installieren, entfernen, Abhängigkeiten mit Versionsbedingungen, Transaktionen mit Rücknahme, `pre_remove`, gescheiterte Install-Skripte sichtbar, signierter Repository-Index, Downgrade-Schutz, nur https) | `packages/base/vpkg/`, [docs/vpkg.md](docs/vpkg.md) | 31 Tests im CI, Selbsttest im gebooteten Abbild ([Phase 6](docs/phase6.md)) |
| Paketsignaturen (Ed25519), Paket-Repository als CI-Artefakt | `packages/base/veyra-keyring/`, [docs/signaturen.md](docs/signaturen.md) | eingebaut, Schlüssel `veyra-2026` aktiv |
| Abbild und Boot-Test in QEMU (Phase 5) | `image/`, Job `image` | bootet bis zum Login (UEFI, ohne Bootloader, 6,4 s ab QEMU-Start mit KVM, [Messwerte](docs/messwerte.md)) |
| Entwicklungs- und Testabbild getrennt: im Testabbild root gesperrt bis zur Ersteinrichtung (root-Passwort, erster Benutzer), Prüfung von Konten und Rechten | `packages/base/veyra-konten/`, `image/build-image.sh` (`VARIANTE=test`) | 17 Konten- und 4 Abbild-Tests, Testabbild bootet in QEMU (CI) |
| Installer `veyra-install` (Kommandozeile): ganzer Datenträger, GPT mit EFI-Partition und ext4, Bestätigung per Gerätenamen, erkennt vorhandene Systeme, Konten schon bei der Installation, alte Partitionstabelle bei Fehler zurück, Warnung bei zwei Veyra-Platten | `packages/base/veyra-installer/`, [docs/installation.md](docs/installation.md) | 20 Tests auf virtuellen Platten; Installation auf leere Platte und Boot mit Selbsttest in QEMU (CI); Ersteinrichtung, Anmeldung und Neustart in QEMU (`image/install-test.py`, CI); nie auf echter Hardware |
| Wurzelzertifikate für https (Mozilla-CA-Bündel aus certifi) | `packages/base/veyra-zertifikate/` | Selbsttest „TLS“ im CI (github.com per TLS 1.3 geprüft) |
| Netzwerk per Kabel (DHCP, Namensauflösung), Prüfung auf fehlgeschlagene Dienste und sauberes Herunterfahren | `packages/base/veyra-netzwerk/`, `image/boot-test.sh`, [Phase 6](docs/phase6.md) | in QEMU getestet (Abbild und Live-ISO), nicht auf echter Hardware |

## Bauen

Alles wird in GitHub Actions gebaut (Reiter **Actions**, Workflow **Toolchain**).
Lokal geht es genauso mit Docker:

```bash
docker build -t veyra-bootstrap build/container
mkdir -p out
docker run --rm -v "$PWD:/repo:ro" -v "$PWD/out:/out" veyra-bootstrap /repo/build/scripts/ci-toolchain.sh
```

VPKG-Tests (brauchen `zstd`, `openssl`, `python3`; am besten ohne root, sonst wird der
Test mit schreibgeschützten Verzeichnissen übersprungen):

```bash
bash tests/vpkg/run.sh
bash tests/vpkg/vpkg-test.sh
```

## Dokumentation

- [ROADMAP.md](ROADMAP.md): tatsächlicher Stand und nächste Aufgaben (P0 bis P4)
- [docs/SYSTEM_STATUS.md](docs/SYSTEM_STATUS.md): Kurzstatus aller Subsysteme
- [docs/FULL_SYSTEM_AUDIT.md](docs/FULL_SYSTEM_AUDIT.md): vollständige Analyse je Subsystem
- [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md): Phasenplan bis Release 1.0
- [docs/architecture.md](docs/architecture.md): Architektur und Entscheidungen
- [docs/vpkg-format.md](docs/vpkg-format.md): Paket- und Rezeptformat
- [docs/vpkg.md](docs/vpkg.md): Bedienung von VPKG 0.5
- [docs/installation.md](docs/installation.md): Veyra mit `veyra-install` installieren
- [docs/phase6.md](docs/phase6.md): Phase 6, Bestandsaufnahme und VPKG-Transaktionen
- [docs/signaturen.md](docs/signaturen.md): Paketsignaturen
- [docs/virtualbox.md](docs/virtualbox.md): Veyra in VirtualBox starten (fertige VDI-Festplatte)
- [docs/hardware-test.md](docs/hardware-test.md): Test auf echter Hardware vom USB-Stick (Phase 6)
- [docs/messwerte.md](docs/messwerte.md): Bootzeit und Ressourcen (VM)
- [docs/build-guide.md](docs/build-guide.md): Bauablauf, Quellen und Lizenzen

## Lizenz

Eigener Code (Skripte, VPKG, Dokumentation): MIT, siehe [LICENSE](LICENSE).
Fremde Quellen behalten ihre eigenen Lizenzen, siehe [LICENSES/README.md](LICENSES/README.md).
