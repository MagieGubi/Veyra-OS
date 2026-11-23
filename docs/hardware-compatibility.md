# Hardware-Kompatibilität

Getrennt nach Nachweis: **QEMU** heißt im CI in einer virtuellen Maschine geprüft,
**Hardware** heißt auf einem echten Rechner geprüft. Was nur in QEMU lief, gilt für echte
Hardware als ungeprüft.

## MSI Katana 15 B13VFK (Intel Core i7-13620H, Intel UHD + NVIDIA RTX 4060)

Stand 0.7: noch nicht getestet. Anleitung: docs/hardware-test-0.7.md.

| Bereich | Treiber / Paket | QEMU | Hardware |
| --- | --- | --- | --- |
| Start vom USB-Stick (UEFI) | Kernel, systemd-boot | ✅ | offen |
| NVMe (nur lesen) | nvme | – | offen |
| Intel-Grafik | i915 (Modul seit 0.7, damit die Firmware beim Laden bereitliegt), veyra-firmware-intel-grafik | – | offen |
| NVIDIA-Grafik | – | – | nicht unterstützt (nur Intel-Grafik) |
| WLAN | iwlwifi, iwd, veyra-firmware-intel-wlan | WPA2, WPA3, DHCP, IPv6, Autoconnect (mac80211_hwsim) | offen |
| Ethernet | r8169 u. a. | ✅ (virtio) | offen |
| Bluetooth | btusb/btintel, BlueZ, veyra-firmware-intel-bluetooth | suchen, koppeln, verbinden (hci_vhci) | offen |
| Lautsprecher, Kopfhörer | snd_hda_intel, Realtek-Codec, PipeWire | Wiedergabe gemessen (intel-hda) | offen |
| Eingebautes Mikrofon | HD-Audio; SOF nicht aktiviert | Aufnahmeweg | offen |
| Akku, Netzteil | ACPI, veyra-power | – (QEMU hat keinen Akku) | offen |
| Ruhezustand | s2idle/S3, veyra-power | S3 von der Echtzeituhr geweckt; s2idle nur per Ein-Taste | offen |
| Tastatur, Touchpad | i8042, i2c-hid | – | offen |

## Grafik anderer Hersteller

| Grafik | Treiber / Paket | Stand |
| --- | --- | --- |
| AMD Radeon ab Vega, Ryzen-APUs ab Raven (2018), RDNA 1 bis 4 (RX 5000 bis 9000) | amdgpu (Modul), veyra-firmware-amd-grafik | gebaut; nie auf Hardware geprüft (QEMU hat keine AMD-Grafik) |
| AMD Radeon älter (HD 7000 bis RX 500) | – | nicht unterstützt (Bild nur über den EFI-Framebuffer) |
| NVIDIA | – | nicht unterstützt: nichts Proprietäres; nouveau ist aus, weil es auf neuen Karten weder Takt noch Energiesparen steuert. Das Bild kommt von der Intel- oder AMD-Grafik des Prozessors |

`veyra-hwinfo firmware` zeigt, welches Firmware-Paket ein Rechner braucht.

## Andere Rechner

Noch keine Berichte. Ein Bericht ist die Datei `veyra-hardwaretest.txt` aus dem Laptop-
Testabbild (docs/hardware-test-0.7.md).
