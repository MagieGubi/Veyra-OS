# Kernel-Konfiguration

Die Konfiguration entsteht reproduzierbar aus zwei Teilen:

1. **Basis:** `make x86_64_defconfig` des gepinnten Linux-Quellbaums (Upstream-Standard).
2. **Veyra-Fragmente:** `veyra-*.config` in diesem Verzeichnis, alphabetisch per
   `scripts/kconfig/merge_config.sh` darübergelegt.

Jede Zeile in einem Fragment hat einen Kommentar mit Begründung. Performance-Änderungen
kommen erst mit Messung gegen diese Referenz (siehe docs/architecture.md).

Core 0.1 zielt auf eine QEMU-VM (UEFI, virtio). `veyra-30-hardware.config` ergänzt für
Phase 6 echte Laptops mit Intel-CPU (NVMe, Start vom USB-Stick, Intel-Grafik, Tastatur,
Touchpad, WLAN-Treiber). `veyra-88-amdgpu.config` (0.7) baut amdgpu als Modul; NVIDIA bleibt aus
(docs/hardware-compatibility.md).
