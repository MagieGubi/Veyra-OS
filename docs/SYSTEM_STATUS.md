# Veyra OS: Systemstatus

Stand: 14.11.2026. Kurzübersicht, was nachweislich funktioniert. Details und Begründungen:
[FULL_SYSTEM_AUDIT.md](FULL_SYSTEM_AUDIT.md), Planung: [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md),
Aufgaben mit Akzeptanzkriterien: [../ROADMAP.md](../ROADMAP.md).

Alle Laufzeit-Nachweise stammen aus QEMU mit KVM im CI. **Auf echter Hardware und in
VirtualBox ist Veyra bisher nie gestartet worden.**

Status: ✅ funktioniert (mit Nachweis) · 🟡 umgesetzt, Nachweis steht aus · 🔧 teilweise ·
⬜ fehlt

| Subsystem | Status | Nachweis / Stand |
| --- | --- | --- |
| Build-System (Stufen 1 bis 5 in GitHub Actions) | ✅ | Lauf [43653042098](https://github.com/MagieGubi/Veyra-OS/actions/runs/43653042098), alle Jobs grün; Quellen gepinnt (`check-pinned.sh`: 0 offen) |
| Cross-Toolchain (GCC 15.2.0, glibc 2.42) | ✅ | CI |
| Kernel 6.18.56-veyra2 | ✅ | zwei unabhängige Builds bit-identisch (Job „Kernel reproduzierbar?“) |
| Basissystem (68 Pakete, glibc bis systemd 257.8) | ✅ | CI Stufe 4b; reproduzierbar ungeprüft |
| VPKG 0.4 (Installieren, Entfernen, Abhängigkeiten mit Versionsbedingungen, Konflikte, Transaktionen, Signaturen, signierter Index) | 🟡 | 0.3 mit CI-Nachweis; Versionsbedingungen lokal getestet (27 Tests als root, 28 ohne root), CI steht aus |
| VPKG: Gruppen, Metapakete, Cache, Mirrors, HTTPS mit Mirror-Liste | ⬜ | – |
| Paket-Repository | 🔧 | wird pro Lauf als CI-Artefakt gebaut und signiert (7 Tage); kein dauerhaftes Online-Repository |
| Boot (UEFI, Kernel direkt als `BOOTX64.EFI`) | ✅ | Login nach etwa 7 s in QEMU |
| Live-ISO (eigenes Init, SquashFS, Overlay) | ✅ | Boot von virtueller CD, Selbsttest OK |
| Entwicklungs- und Testabbild getrennt, root gesperrt bis zur Ersteinrichtung | ✅ | Lauf [43653042098](https://github.com/MagieGubi/Veyra-OS/actions/runs/43653042098): 17 Konten- und 4 Abbild-Tests, Testabbild bootet, Selbsttest „Konten und Rechte: ok“; Ersteinrichtung nur per Test geprüft |
| Benutzerverwaltung | 🔧 | shadow ohne PAM; Ersteinrichtung legt einen Benutzer in `wheel` an; `sudo` fehlt |
| Netzwerk per Kabel (DHCP, DNS), keine offenen Ports | ✅ | Selbsttest in QEMU (e1000e) |
| WLAN, Bluetooth, Audio, Firewall, Zeitsynchronisierung, Drucker | ⬜ | – |
| Hardware (NVMe, USB, Intel-Grafik, Tastatur) | 🔧 | Treiber im Kernel, nie auf echter Hardware geprüft |
| Firmware | ⬜ | `regulatory.db` fehlt laut Kernel-Log |
| Installer | ⬜ | – |
| Updates und Rollback des Systems | ⬜ | nur Paket-Transaktionen mit Rücknahme |
| Recovery | 🔧 | Live-ISO startet; kein dokumentierter Rettungsablauf |
| Grafische Oberfläche | ⬜ | – |
| CI-Prüfungen | ✅ | shellcheck, VPKG-, Diagnose-, Konten- und Abbild-Tests, Kernel-Reproduzierbarkeit, Boot-Tests von Platte und CD mit Selbsttest und sauberem Herunterfahren |
