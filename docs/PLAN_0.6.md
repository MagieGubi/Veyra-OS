# Veyra OS 0.6: Foundation & Usability, Plan

Stand: 17.11.2026, Grundlage ist `main` nach 0.5.0 (Commit fceb484) und die Vorgabe
„Master Development Prompt Veyra OS 0.6“. Ausgangslage: [release-0.5.md](release-0.5.md),
[SYSTEM_STATUS.md](SYSTEM_STATUS.md).

Status-Wörter wie in der Vorgabe: implementiert · getestet (lokal) · in CI nachgewiesen ·
auf echter Hardware getestet · geplant.

## 1. Ausgangslage (aus Code und CI, nicht aus der Roadmap)

| Bereich | Stand 0.5 | Lücke für 0.6 |
| --- | --- | --- |
| Build | 5 Stufen in GitHub Actions, Quellen gepinnt, Kernel bit-identisch | Basispakete und Abbild nicht auf Reproduzierbarkeit geprüft (P1-4); neue Pakete brauchen einen Platz in der Kette |
| Kernel 6.18.56-veyra2 | `x86_64_defconfig` + Veyra-Fragmente, `CONFIG_MODULE_SIG=n` | Härtung und nftables-Optionen nicht geprüft, keine Modulsignaturen |
| Benutzer | shadow ohne PAM, root gesperrt bis zur Ersteinrichtung, `su` nur für `wheel` | kein PAM, kein sudo, Dateirechte nur teilweise geprüft |
| Netzwerk | Kabel per systemd-networkd/resolved, keine offenen Ports | keine Firewall, kein WLAN, keine Zeitsynchronisierung geprüft |
| VPKG 0.5 | Transaktionen, Signaturen, Index-Stand, https | eine Quelle, kein Cache, keine Spiegel, keine Gruppen, keine `update/search/clean/repo` |
| Boot | Kernel direkt als `BOOTX64.EFI`, `PARTLABEL=veyra-root` | kein Bootloader, kein zweiter Kernel, kein Rückfall, kein Recovery-Ablauf |
| Hardware | Treiber für Intel-Laptops im Kernel, nie auf echter Hardware | keine Firmware, kein `veyra-hwinfo` |
| Oberfläche | keine | Grafikstack fehlt komplett |

## 2. Neue Pakete und wo sie gebaut werden

Neue Basispakete kommen in eine **Stufe 4b, Teil 4** (eigener CI-Job nach Teil 3). So baut
eine Änderung dort nicht die Teile 1 bis 3 neu. Jede Quelle wird per Signatur oder mit
einer zweiten unabhängigen Prüfsumme festgelegt, wie bisher.

| Paket | Zweck | Phase |
| --- | --- | --- |
| libmnl, libnftnl, nftables | Firewall | 2 |
| linux-pam (optional, siehe Entscheidung 1), sudo | Rechteverwaltung | 2 |
| wireless-regdb, iwd (mit ell) | WLAN, Funkregeln | 5 |
| veyra-firmware-* aus linux-firmware | Firmware je Gerätegruppe, mit Lizenzdateien | 5 |
| pciutils-Daten (pci.ids) oder eigene sysfs-Auswertung | `veyra-hwinfo` | 5 |
| libdrm, wayland, wayland-protocols, libxkbcommon, pixman, libevdev, mtdev, libinput, seatd, Mesa (ohne LLVM), Compositor | Desktop-Grundlage | 6 |

## 3. Plan nach Phasen

### Phase 2: Sicherheit und Stabilität
1. **Firewall (nftables):** Paket `veyra-firewall` mit Regeln in
   `/etc/nftables.d/`, Standard: eingehend verwerfen, Loopback, Antworten auf eigene
   Verbindungen, DHCPv4/v6-Antworten und ICMPv6 für IPv6 erlauben. Dienst lädt die Regeln
   vor dem Netz. Test: Regelsatz lokal mit `nft -c` prüfen; im Selbsttest
   `nft list ruleset` gegen das Soll und ein Portscan aus dem Host (QEMU hostfwd) muss
   scheitern.
2. **Kernel-Härtung:** Fragment `veyra-50-security.config` nur mit Optionen, die der
   Kernel 6.18 wirklich hat (`STACKPROTECTOR_STRONG`, `FORTIFY_SOURCE`, `INIT_ON_ALLOC`,
   `RANDOMIZE_BASE`, `STRICT_KERNEL_RWX`, `SECURITY_LOCKDOWN_LSM`, Yama, `DEVMEM` aus, nur
   benötigte nftables-Module). Sysctl-Datei (`kernel.kptr_restrict`, `dmesg_restrict`,
   `yama.ptrace_scope`, `fs.protected_*`, `net.ipv4.conf.*.rp_filter`). Test: CI prüft
   die fertige `.config`, der Selbsttest liest die Sysctl-Werte.
3. **Selbsttest mit Bericht:** zusätzlich zur Konsole ein maschinenlesbarer Bericht
   (`/var/lib/veyra/selbsttest.json`), neue Prüfungen: Firewall, Dateirechte wichtiger
   Pfade, Kernelversion, Bootkonfiguration.
4. **Benutzer:** Entscheidung 1 unten. Kein root-Login ohne Passwort bleibt Pflicht (ist
   in 0.5 nachgewiesen).

### Phase 3: VPKG 0.6
`vpkg update` (Index holen und prüfen), `search`, `clean`, `repo list`; mehrere Quellen in
`/etc/vpkg/repos.d/*.conf` mit Spiegel-Liste je Quelle (gleicher Index-Stand und gleiche
Signatur nötig); Paket-Cache unter `/var/cache/vpkg` mit Prüfsumme vor jeder Nutzung;
abgebrochene Downloads werden als `.teil` verworfen; Paketgruppen über ein Feld `groups`
im Manifest und Metapakete (leere Pakete mit Abhängigkeiten) `veyra-base`,
`veyra-network`, `veyra-security`, `veyra-development`, `veyra-recovery`. Bestehende Befehle
und das Paketformat bleiben kompatibel; ein neues Manifest-Feld bekommt eine
Formatversion. *Umgesetzt (18.11.):* `groups` ist optional und wird von VPKG bis 0.5 einfach
nicht gelesen; eine neue Formatversion hätte ältere VPKG jedes Paket ablehnen lassen. Das
Format bleibt deshalb `format = 1` (docs/vpkg-format.md, „Gruppen“). Test: Erweiterung von `tests/vpkg/vpkg-test.sh` mit lokalem
https-Server, zwei Spiegeln (einer kaputt), abgebrochenem Download.

### Phase 4: Boot und Recovery
1. **systemd-boot** (systemd mit `-Dbootloader=enabled` neu bauen, dafür pyelftools
   gepinnt) mit Einträgen per `PARTUUID`, zwei Kernel (aktuell und letzter bekannter
   guter), Zeitlimit, Rückfall über Boot-Zähler (`systemd-bless-boot`). Der Direktstart
   aus 0.5 bleibt als Rückfallweg im Installer wählbar, bis der neue Weg im CI grün ist.
2. **Kernel-Update:** `veyra-kernel-update` legt den neuen Kernel neben den alten, prüft
   die EFI-Datei, schreibt den Eintrag, markiert ihn als „zu testen“; erst ein
   erfolgreicher Start macht ihn zum Standard.
   *Umgesetzt (18.11.):* Schritte 1 und 2 sind im CI grün (Lauf 44410970865): Installation
   mit systemd-boot, Bestätigung nach gutem Start, kaputter Kernel fällt nach drei
   Fehlstarts auf den alten zurück. Nur in QEMU geprüft.
3. **Recovery:** `veyra-recovery` in der Live-ISO: installierte Systeme finden, `fsck`,
   `vpkg check` und `recover` im Zielsystem, Booteinträge reparieren, Kernel-Rückfall,
   Logs zeigen, Kontenprüfung. Test in QEMU: absichtlich kaputter Booteintrag und
   kaputtes Paket, Recovery repariert, Platte startet wieder.
   *Umgesetzt (19.11.):* grün in Lauf 44426903469, Ablauf in docs/recovery.md.

### Phase 5: Hardware und Netzwerk
Firmware aus einem gepinnten linux-firmware-Archiv, aufgeteilt nach Gerätegruppen
(zuerst Intel-WLAN und Intel-Grafik für Adrians Laptop), jede mit `WHENCE`-Auszug und
Lizenz. iwd für WPA2/WPA3, `wireless-regdb`, systemd-timesyncd. Werkzeuge
`veyra-hwinfo` (liest sysfs, gibt Text und JSON aus, aktiviert nichts) und
`veyra-network` (Geräte, WLAN-Netze, verbinden, Status, DNS-Test, Diagnose ohne
Passwörter). Test in QEMU: hwinfo-Ausgabe gegen die bekannte VM-Hardware, iwd startet
ohne Gerät sauber. **WLAN selbst geht nur auf echter Hardware zu prüfen.**
*Stand 19.11. (Lauf 44426903469):* veyra-hwinfo, veyra-network, Firmware-Paket für Intel-WLAN
(AX201, AX210, AX211, Dateien einzeln gepinnt), ell, iwd und wireless-regdb aus Quellcode
(GPG-geprüft), Kernel 6.18.56-veyra5 mit cfg80211/mac80211 als Module. In QEMU erkennt iwd ein
virtuelles Funkgerät. Offen: i915-Firmware (Treiber ist fest eingebaut, lädt vor der Root-Partition).

### Phase 6: Desktop-Grundlage (experimentell)
Grafikstack aus Quellcode in einer eigenen Stufe (nicht im Basissystem): libdrm, Wayland,
libinput, seatd, Mesa ohne LLVM (Treiber iris, softpipe für QEMU), ein schlanker
Compositor als Prototyp. Ziel für 0.6 ist nur: In QEMU startet eine Wayland-Sitzung mit
Terminal (kitty, wie im Projektziel) über virtio-gpu, Screenshot im CI. Das Basissystem
startet unverändert ohne diese Pakete.

### Phase 7: Integration und Release
Voller CI-Lauf, Reproduzierbarkeitsjob für die eigenen Pakete und Stufe 4b (P1-4),
Dokumentation (`veyra-06.md`, `security.md`, `recovery.md`, `network.md`, `hardware.md`,
`desktop.md`), Version 0.6.0. Release nur mit Adrians Freigabe.

## 4. Reihenfolge und erste Aufgabe

Firewall und Kernel-Härtung zuerst (Vorgabe: kritisch, und sie ändern nichts an der
Bootkette). Dann VPKG 0.6, dann Boot und Recovery, dann Firmware und WLAN, dann der
Desktop-Prototyp. Jede Phase ist erst fertig, wenn ihr Test im CI grün ist.

## 5. Entscheidungen

1. **PAM und sudo:** Empfehlung: `sudo` ohne PAM (mit shadow-Unterstützung) für `wheel`,
   PAM erst mit dem grafischen Login-Manager in 0.8, weil PAM dann ohnehin nötig ist und
   jedes Programm mit Anmeldung neu gebaut werden muss.
2. **Modulsignaturen:** Ein Signaturschlüssel pro Build macht den Kernel nicht mehr
   bit-identisch; ein fester Schlüssel müsste wie der VPKG-Schlüssel als Secret liegen.
   Empfehlung für 0.6: weiter ohne Module-Signatur, dafür nötige Treiber fest im Kernel
   und `CONFIG_MODULES` so klein wie möglich; Secure Boot und Signaturen zusammen in einer
   späteren Version.
3. **Compiler im installierten System:** Empfehlung: Gruppe `veyra-development`, der
   Installer kopiert sie nur auf Wunsch. Das verkleinert die Angriffsfläche und das System
   von knapp 6 GiB.
