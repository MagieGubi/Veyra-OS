# Veyra OS 0.7 „Connectivity“: Audit und Plan

Stand: 21.11.2026. Grundlage ist `main` nach 0.6.0 (Commit ce361a0, CI-Lauf
[44810135273](https://github.com/MagieGubi/Veyra-OS/actions/runs/44810135273), alle 16 Jobs
grün) und Adrians Vorgabe für 0.7 (Kopie in `/mnt/project-files/veyra/specs/`).
Adrians Entscheidung vom 21.11.: kein GitHub-Release für 0.6, Releases erst ab 1.0.

## 1. Audit: Was 0.6 für 0.7 schon mitbringt

| Bereich | Stand nach 0.6 | Lücke für 0.7 |
| --- | --- | --- |
| Ethernet, DHCP, DNS | systemd-networkd und -resolved, Selbsttest in QEMU | IPv6 nicht geprüft |
| WLAN | iwd 3.12, wireless-regdb, `veyra-network` (status, geraete, wlan liste/verbinde/trenne, dns-test, diagnose ohne Passwörter und MAC); in QEMU nur mac80211_hwsim erkannt | Verbindung mit WPA2/WPA3 nie getestet, Autoconnect und Netzwerk-Config für WLAN-Geräte unklar, nie auf echter Hardware |
| Firmware | ein Paket `veyra-firmware-intel-wlan`, Dateien einzeln gepinnt | kein allgemeines Schema (Version, Lizenz, Hardware-Zuordnung), i915-, Bluetooth- und SOF-Firmware fehlen |
| Bluetooth | nichts: kein Kernel-Teil, kein BlueZ | alles |
| Audio | nur `SND_HDA_INTEL` aus defconfig; kein alsa-lib, kein PipeWire | alles; Intel-Laptops ab 2019 brauchen für eingebaute Mikrofone oft SOF |
| Grafik | Mesa ohne LLVM (softpipe, virgl, svga), Kernel i915, virtio-gpu, vmwgfx | AMD (amdgpu-Kernel und Firmware; radeonsi braucht LLVM), NVIDIA nur dokumentieren |
| Energie | systemd-logind läuft, sonst nichts | `veyra-power`, Suspend/Resume, Akku, CPU-Energiemodi |
| Hardware-Info | `veyra-hwinfo`: CPU, RAM, Datenträger, Netzwerk, Grafik, PCI, USB, Geräte ohne Treiber | Bluetooth, Audio, Touchpad/Eingabe, Bildschirm (EDID), Firmware-Vorschläge |
| VPKG | 0.6 mit Gruppen und Metapaketen | Hardware-Gruppen, Firmware-, Audio-, Netzwerk-Metapakete |
| Fehlende Grundbausteine | glib2 (für BlueZ, PipeWire, WirePlumber), Lua (WirePlumber), alsa-lib, sbc (Bluetooth-Audio), libusb | müssen aus Quellcode in eine neue Stufe |

## 2. Was sich in QEMU prüfen lässt und was nicht

In QEMU (im CI, ehrlich als „QEMU“ dokumentiert):
- Audio: `intel-hda` mit `hda-duplex`, QEMU schreibt die Ausgabe in eine WAV-Datei; der Test
  spielt über PipeWire einen Ton und prüft die WAV-Datei auf Signal. Aufnahme: Stream-Aufbau
  und Pegel über die QEMU-Eingabe.
- Bluetooth: virtuelle Controller über `hci_vhci` (BlueZ-Emulator `btvirt`); Erkennung,
  Pairing und Verbindung zwischen zwei virtuellen Controllern.
- WLAN: `mac80211_hwsim` mit zwei Funkgeräten, eins als Zugangspunkt (hostapd nur im Test),
  WPA2 und WPA3-SAE verbinden, DHCP, Autoconnect nach Neustart.
- Suspend/Resume: QEMU mit S3, Aufwecken per `rtcwake`.
- USB: `qemu-xhci` mit USB-Tastatur, -Speicher und -Audio.
- Fehlerfälle: fehlende Firmware, fehlendes Gerät, kaputte Firmware-Datei.

Nur auf echter Hardware (Adrians Laptop, MSI Katana 15 B13VFK; Ergebnisse getrennt in
`docs/hardware-compatibility.md`): WLAN mit echtem Router, Bluetooth-Kopfhörer und -Maus,
Lautsprecher und eingebautes Mikrofon, Intel-Grafik, Akku, Suspend. **Die Release-Kriterien
von 0.7 verlangen diese Tests; ohne sie wird 0.7 nicht als fertig gemeldet.**

## 3. Plan (Reihenfolge)

1. **Stufe 6 „Connectivity-Grundlage“:** glib2, Lua 5.4, alsa-lib, alsa-utils, libusb, sbc,
   libical aus Quellcode, GPG- oder doppelt geprüft wie in Stufe 5.
2. **Audio:** Kernel (HDA-Codecs, USB-Audio, SOF als Modul), PipeWire, WirePlumber,
   Pulse-Kompatibilität (pipewire-pulse), Paket `veyra-audio` mit gemeinsamer Schnittstelle
   `veyra-audio` (Geräte, Standardgerät, Lautstärke, Test). QEMU-Test mit WAV-Ausgabe.
3. **Bluetooth:** Kernel (BT, btusb, btintel, hci_vhci), BlueZ, Paket `veyra-bluetooth`,
   Bluetooth-Audio über PipeWire. QEMU-Test mit zwei virtuellen Controllern.
4. **WLAN fertig machen:** WPA2/WPA3-Test mit hwsim und hostapd, Autoconnect,
   IPv6, `veyra-network` um IP- und Verbindungsanzeige erweitern.
5. **Firmware-System:** einheitliche Firmware-Pakete (Version, SHA-256 je Datei, Lizenzdatei,
   Hardware-Zuordnung über Modalias/PCI-IDs), `veyra-hwinfo firmware` schlägt fehlende
   Pakete vor; i915, Intel-Bluetooth, SOF, amdgpu.
6. **Energie:** `veyra-power` (Akku, Netzteil, CPU-Governor/EPP, Suspend-Zustände,
   logind-Einstellungen), Suspend/Resume-Test in QEMU.
7. **veyra-hwinfo und VPKG-Gruppen:** Bluetooth, Audio, Eingabe, EDID; Metapakete
   `veyra-audio`, `veyra-bluetooth`, `veyra-firmware`, Hardware-Gruppen.
8. **Grafik:** amdgpu im Kernel (Modul) mit Firmware; NVIDIA als eigene
   Kompatibilitätsstufe nur dokumentiert (nouveau optional, nichts Proprietäres).
9. **Doku und Hardware-Tests:** `network.md`, `bluetooth.md`, `audio.md`,
   `hardware-compatibility.md`, `power-management.md`, `veyra-07.md`; Testanleitung für
   Adrians Laptop.

Jeder Schritt ist erst fertig, wenn sein Test im CI grün ist.
