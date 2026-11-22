# Veyra OS: Systemstatus

Stand: 22.11.2026, Veyra OS 0.6.0 plus 0.7 in Arbeit (QEMU-Nachweise; Hardwaretest steht aus). Kurzübersicht, was nachweislich funktioniert. Details und Begründungen:
[FULL_SYSTEM_AUDIT.md](FULL_SYSTEM_AUDIT.md), Planung: [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md),
Aufgaben mit Akzeptanzkriterien: [../ROADMAP.md](../ROADMAP.md).

Alle Laufzeit-Nachweise stammen aus QEMU mit KVM im CI. **Auf echter Hardware und in
VirtualBox ist Veyra bisher nie gestartet worden.**

Status: ✅ funktioniert (mit Nachweis) · 🟡 umgesetzt, Nachweis steht aus · 🔧 teilweise ·
⬜ fehlt

| Subsystem | Status | Nachweis / Stand |
| --- | --- | --- |
| Build-System (Stufen 1 bis 5 in GitHub Actions) | ✅ | Lauf [44731627264](https://github.com/MagieGubi/Veyra-OS/actions/runs/44731627264), alle 16 Jobs grün; Quellen gepinnt (`check-pinned.sh`: 0 offen) |
| Cross-Toolchain (GCC 15.2.0, glibc 2.42) | ✅ | CI |
| Kernel 6.18.56-veyra6 | ✅ | zwei unabhängige Builds bit-identisch (Job „Kernel reproduzierbar?“) |
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
| WLAN (iwd 3.12, hostapd nur im Test, `veyra-network wlan`) | ✅ | QEMU mit mac80211_hwsim: WPA2-PSK und WPA3-SAE verbunden, DHCP, IPv6 per SLAAC, Autoconnect nach Neustart, Passwortdatei nur für root ([Lauf 44969457995](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995)); echtes WLAN nie geprüft |
| Firmware-Pakete (`veyra-firmware-intel-wlan`, `-intel-grafik`, `-intel-bluetooth`, SHA-256 je Datei, Lizenz, Hardware-Zuordnung; `veyra-hwinfo firmware`) | 🔧 | Selbsttest prüft Prüfsummen; nie auf echter Hardware geladen |
| Ton (PipeWire, WirePlumber, pipewire-pulse, `veyra-audio`) | ✅ | QEMU: Testton kommt als WAV auf dem Wirt an (Pegel und Frequenz gemessen), aplay über PipeWire, Aufnahmeweg, Rechte über Gruppe `pipewire` ([Lauf 44969457995](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995)); nie auf echter Hardware, SOF noch aus |
| Bluetooth (BlueZ, `veyra-bluetooth`) | ✅ | QEMU mit zwei virtuellen Controllern: suchen, koppeln, verbinden, trennen, entfernen; nur Gruppe `bluetooth` hat Zugriff ([Lauf 44969457995](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995)); nie auf echter Hardware |
| Energie (`veyra-power`: Profile, Ruhezustand, logind) | 🔧 | QEMU: S3 von der Echtzeituhr geweckt, s2idle nur per Ein-Taste geweckt, Profil übersteht Neustart ([Lauf 44969457995](https://github.com/MagieGubi/Veyra-OS/actions/runs/44969457995)); Akku und CPU-Takt nur auf Hardware |
| Drucker | ⬜ | – |
| Hardware (NVMe, USB, Intel-Grafik, Tastatur) | 🔧 | Treiber im Kernel, nie auf echter Hardware geprüft; `veyra-hwinfo` zeigt Geräte ohne Treiber |
| Installer 0.3 (`veyra-install`, Kommandozeile, ganzer Datenträger, GPT mit ESP und ext4, Konten bei der Installation, alte Partitionstabelle bei Fehler zurück) | ✅ | Lauf [44114798590](https://github.com/MagieGubi/Veyra-OS/actions/runs/44114798590): Installation auf leere 8-GiB-Platte; erster Start mit Ersteinrichtung, Anmeldung als neuer Benutzer, `su`, Neustart, Anmeldung als root; 20 Installer-Tests; nie auf echter Hardware |
| Mehrere Veyra-Platten | ✅ | Neue Installationen starten über `PARTUUID` die eigene Partition; nur beim Direktstart warnt die Startprüfung weiterhin |
| Updates und Rollback des Systems | ⬜ | nur Paket-Transaktionen mit Rücknahme |
| Recovery (`veyra-recovery` in der Live-ISO, docs/recovery.md) | ✅ | QEMU: Booteintrag und Paketdatei beschädigt, Platte startet nicht, Reparatur von der Live-ISO, startet wieder ([Lauf](https://github.com/MagieGubi/Veyra-OS/actions/runs/44426903469)); nie auf echter Hardware |
| Grafische Sitzung (cage mit kitty, Wayland, Mesa ohne LLVM; [desktop.md](desktop.md)) | 🔧 | QEMU mit virtio-gpu: cage und kitty laufen als normaler Benutzer, Bildschirmfoto im CI ([Lauf 44721414747](https://github.com/MagieGubi/Veyra-OS/actions/runs/44721414747)); nur Software-Darstellung, kein Intel-Treiber iris; nie auf echter Hardware |
| CI-Prüfungen | ✅ | shellcheck, VPKG-, Diagnose-, Konten- und Abbild-Tests, Kernel-Reproduzierbarkeit, Boot-Tests von Platte und CD mit Selbsttest und sauberem Herunterfahren |
