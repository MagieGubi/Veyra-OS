# Netzwerk (Veyra 0.7)

Installieren: `vpkg install @veyra-network` (im Grundsystem enthalten). Firmware für Intel-WLAN:
`vpkg install veyra-firmware-intel-wlan`.

| Teil | Aufgabe |
| --- | --- |
| systemd-networkd | Adressen per DHCP (IPv4) und Router-Anzeige/SLAAC (IPv6) für Kabel und WLAN |
| systemd-resolved | Namensauflösung; LLMNR und mDNS aus (kein offener Port) |
| iwd 3.12 | WLAN-Anmeldung: WPA2-Personal, WPA3-Personal (SAE), bekannte Netze automatisch |
| veyra-firewall | eingehend gesperrt außer Antworten, DHCP-Antworten und ICMP |
| veyra-network | Werkzeug (unten) |

## veyra-network

```
veyra-network [status]                      Geräte, Adressen, Standardroute, DNS, Zeitabgleich
veyra-network geraete
veyra-network wlan liste                    Netze in Reichweite
veyra-network wlan verbinde NETZ            iwctl fragt das Passwort ab (ohne Echo)
veyra-network wlan verbinde NETZ --passwort-stdin    für Skripte: Passwort von der Standardeingabe
veyra-network wlan status                   verbundenes Netz, Sicherheit (WPA2/WPA3), Signal, Adressen
veyra-network wlan trenne
veyra-network wlan vergiss NETZ             gespeichertes Netz löschen
veyra-network dns-test [NAME]
veyra-network diagnose                      ohne Passwörter und MAC-Adressen
```

Gespeicherte Netze liegen in `/var/lib/iwd/` (nur root lesbar). Ein Passwort taucht nie als
Argument in einer Kommandozeile auf. Nach einem Neustart oder Funkloch verbindet iwd
bekannte Netze von selbst.

## Was geprüft ist

| Prüfung | Wo | Ergebnis |
| --- | --- | --- |
| Ethernet mit DHCP, DNS | QEMU (Selbsttest bei jedem Lauf) | ✅ |
| WLAN: zwei virtuelle Funkgeräte (mac80211_hwsim), hostapd als Zugangspunkt, WPA2-PSK und WPA3-SAE, Adresse per DHCP, IPv6 per SLAAC, Autoconnect nach Neustart | QEMU (CI, `image/wlan-test.py`) | siehe CI |
| echter WLAN-Chip mit Firmware, echter Router | echte Hardware | **offen** (docs/hardware-test-0.7.md) |

Grenze des QEMU-Tests: beide Funkgeräte gehören zur selben VM. Datenverkehr zwischen ihnen
nimmt der Kernel intern; geprüft werden deshalb Anmeldung, Schlüsselaustausch, DHCP und
Router-Anzeige, die alle über das virtuelle Funkmedium laufen, nicht ein `ping`.
