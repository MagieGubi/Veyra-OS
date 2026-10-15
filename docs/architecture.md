# Veyra OS: Architektur

Der vollständige, kommentierbare Architekturplan (Phase 1 und 2) liegt hier:
https://claude.ai/code/artifact/6bf7a6af-b6a3-42d5-adf2-1e6db3caa9ff

Diese Datei hält die Entscheidungen fest, die für den Code in diesem Repository gelten.

## Entscheidungen

| Bereich | Entscheidung |
| --- | --- |
| Kernel | Eigener Kernel auf Linux-Basis (`veyra-kernel`): eigener Quellbaum (Fork des Linux-Stable-Trees, LTS-Serie 6.18), eigene Konfiguration, eigenes Patchset, Version `X.Y.Z-veyraN`. Kein unabhängig entwickelter Kernel. |
| Basissystem | Vollständig aus Quellcode gebaut, keine fremde Distribution. Bootstrap nach der Methode von Linux From Scratch. glibc, GCC, systemd. |
| Paketmanager | VPKG, eigenes Format (docs/vpkg-format.md), Ed25519-Signaturen. |
| Boot (Core 0.1) | UEFI, Kernel als EFI-Programm direkt von der Firmware, ext4, keine Initramfs. Später systemd-boot mit UKI, Btrfs mit Snapshots, Secure Boot. |
| Desktop | Keiner standardmäßig. Desktop- und Window-Manager-Profile als VPKG-Metapakete, genau eine Sitzung bei der Installation. Kitty als Standardterminal der Grafikprofile. |
| Telemetrie | Keine. |

## Bootstrap in fünf Stufen

1. **Host-Container** (`build/container/Dockerfile`): Debian, nur Werkzeuge zum Bootstrap.
2. **Cross-Toolchain** (`toolchain/build-cross.sh`): binutils, GCC, Linux-Header, glibc,
   libstdc++ für `x86_64-veyra-linux-gnu`.
3. **Temporäre Werkzeuge** (`temptools/build-temp.sh`): bash, coreutils, make usw. mit der Cross-Toolchain.
4. **Bau im chroot** (`stage4/`): endgültige Basispakete als `.vpkg`, jedes sofort installiert.
5. **Image** (`image/`): GPT-Platte, EFI-Partition mit Kernel, ext4-Root; die Basispakete
   stehen in der VPKG-Datenbank, Zusatzpakete installiert VPKG selbst.

## Ehrliche Grenzen

- VPKG nimmt seit 0.2 abgebrochene Vorgänge per Journal zurück (docs/vpkg.md,
  Transaktionen). Install-Skripte bleiben davon ausgenommen; ein Zurückrollen des ganzen
  Systems kommt erst mit Btrfs-Snapshots.
- Jede Sicherheitskorrektur muss Veyra selbst bauen und ausliefern.
- Bit-identische Builds sind für einzelne Pakete das Ziel; Abweichungen werden dokumentiert,
  nicht verschwiegen.
