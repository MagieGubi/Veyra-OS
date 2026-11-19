# Veyra OS: Systemstatus

Stand: 17.11.2026, Veyra OS 0.5.0. Kurzübersicht, was nachweislich funktioniert. Details und Begründungen:
[FULL_SYSTEM_AUDIT.md](FULL_SYSTEM_AUDIT.md), Planung: [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md),
Aufgaben mit Akzeptanzkriterien: [../ROADMAP.md](../ROADMAP.md).

Alle Laufzeit-Nachweise stammen aus QEMU mit KVM im CI. **Auf echter Hardware und in
VirtualBox ist Veyra bisher nie gestartet worden.**

Status: ✅ funktioniert (mit Nachweis) · 🟡 umgesetzt, Nachweis steht aus · 🔧 teilweise ·
⬜ fehlt

| Subsystem | Status | Nachweis / Stand |
| --- | --- | --- |
| Build-System (Stufen 1 bis 5 in GitHub Actions) | ✅ | Lauf [44114798590](https://github.com/MagieGubi/Veyra-OS/actions/runs/44114798590), alle Jobs grün; Quellen gepinnt (`check-pinned.sh`: 0 offen) |
| Cross-Toolchain (GCC 15.2.0, glibc 2.42) | ✅ | CI |
| Kernel 6.18.56-veyra2 | ✅ | zwei unabhängige Builds bit-identisch (Job „Kernel reproduzierbar?“) |
| Basissystem (68 Pakete, glibc bis systemd 257.8) | ✅ | CI Stufe 4b; reproduzierbar ungeprüft |
| VPKG 0.5 (Installieren, Entfernen, Abhängigkeiten mit Versionsbedingungen, Konflikte, Transaktionen, Signaturen, signierter Index, `pre_remove`, gescheiterte Install-Skripte sichtbar, Netzquellen nur über https) | ✅ | Lauf [44114798590](https://github.com/MagieGubi/Veyra-OS/actions/runs/44114798590), alle Jobs grün; 31 Tests als root, 32 ohne root |
| VPKG 0.6: Quellen mit Spiegeln, Paket-Cache, Gruppen und Metapakete, update/search/clean/repo list | ✅ | 38 VPKG-Tests (zwei Spiegel mit kaputtem und veraltetem, abgebrochener Download, kaputter Cache); Selbsttest „Paketgruppen: ok“ im Lauf [44281705958](https://github.com/MagieGubi/Veyra-OS/actions/runs/44281705958); noch kein öffentliches Repository |
| Wurzelzertifikate (veyra-zertifikate, Mozilla-Bündel aus certifi) | ✅ | Selbsttest „TLS“ im Lauf [44114798590](https://github.com/MagieGubi/Veyra-OS/actions/runs/44114798590): github.com per TLS 1.3 geprüft |
| Paket-Repository | 🔧 | wird pro Lauf als CI-Artefakt gebaut und signiert (7 Tage); kein dauerhaftes Online-Repository |
| Boot (UEFI, systemd-boot mit Boot-Zähler, Einträge per `PARTUUID`) | ✅ | QEMU: Eintrag nach gutem Start bestätigt; Direktstart aus 0.5 bleibt als `--bootweg direkt` wählbar |
| Kernel-Update mit Rückfall (`veyra-kernel-update`) | ✅ | QEMU: kaputter Kernel scheitert dreimal, danach startet der alte; `liste` meldet ihn als schlecht ([Lauf](https://github.com/MagieGubi/Veyra-OS/actions/runs/44410970865)) |
| Live-ISO (eigenes Init, SquashFS, Overlay) | ✅ | Boot von virtueller CD, Selbsttest OK |
| Entwicklungs- und Testabbild getrennt, root gesperrt bis zur Ersteinrichtung | ✅ | 17 Konten- und 4 Abbild-Tests; Ersteinrichtung an Konsole 1 per Tastatur in QEMU eingetippt (`image/install-test.py`, Lauf [44114798590](https://github.com/MagieGubi/Veyra-OS/actions/runs/44114798590)) |
| Benutzerverwaltung | 🔧 | shadow ohne PAM; Ersteinrichtung legt einen Benutzer in `wheel` an; `sudo` fehlt |
| Netzwerk per Kabel (DHCP, DNS), keine offenen Ports | ✅ | Selbsttest in QEMU (e1000e) |
| Firewall (nftables, eingehend und Weiterleiten verworfen) | ✅ | Selbsttest „Firewall: ok“ im Lauf [44263921331](https://github.com/MagieGubi/Veyra-OS/actions/runs/44263921331); [security.md](security.md) |
| Kernel-Härtung (Kernel-Optionen, 19 sysctl-Werte, Yama) | ✅ | Selbsttest „Kernel-Härtung: ok“ im Lauf [44263921331](https://github.com/MagieGubi/Veyra-OS/actions/runs/44263921331) |
| WLAN-Software (iwd 3.12, wireless-regdb, `veyra-network`) | 🔧 | QEMU: iwd läuft und erkennt ein virtuelles Funkgerät (mac80211_hwsim), regulatory.db lädt ([Lauf](https://github.com/MagieGubi/Veyra-OS/actions/runs/44426903469)); echtes WLAN nie geprüft |
| WLAN-Firmware (`veyra-firmware-intel-wlan`, AX201/AX210/AX211) | 🔧 | im Repository und im Testabbild; nie auf echter Hardware geladen |
| Bluetooth, Audio, Drucker | ⬜ | – |
| Hardware (NVMe, USB, Intel-Grafik, Tastatur) | 🔧 | Treiber im Kernel, nie auf echter Hardware geprüft; `veyra-hwinfo` zeigt Geräte ohne Treiber |
| Firmware | ⬜ | `regulatory.db` fehlt laut Kernel-Log |
| Installer 0.3 (`veyra-install`, Kommandozeile, ganzer Datenträger, GPT mit ESP und ext4, Konten bei der Installation, alte Partitionstabelle bei Fehler zurück) | ✅ | Lauf [44114798590](https://github.com/MagieGubi/Veyra-OS/actions/runs/44114798590): Installation auf leere 8-GiB-Platte; erster Start mit Ersteinrichtung, Anmeldung als neuer Benutzer, `su`, Neustart, Anmeldung als root; 20 Installer-Tests; nie auf echter Hardware |
| Mehrere Veyra-Platten | ✅ | Neue Installationen starten über `PARTUUID` die eigene Partition; nur beim Direktstart warnt die Startprüfung weiterhin |
| Updates und Rollback des Systems | ⬜ | nur Paket-Transaktionen mit Rücknahme |
| Recovery (`veyra-recovery` in der Live-ISO, docs/recovery.md) | ✅ | QEMU: Booteintrag und Paketdatei beschädigt, Platte startet nicht, Reparatur von der Live-ISO, startet wieder ([Lauf](https://github.com/MagieGubi/Veyra-OS/actions/runs/44426903469)); nie auf echter Hardware |
| Grafische Oberfläche | ⬜ | – |
| CI-Prüfungen | ✅ | shellcheck, VPKG-, Diagnose-, Konten- und Abbild-Tests, Kernel-Reproduzierbarkeit, Boot-Tests von Platte und CD mit Selbsttest und sauberem Herunterfahren |
