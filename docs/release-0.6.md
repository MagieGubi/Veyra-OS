# Veyra OS 0.6.0: Sicherheit, Boot mit Rückfall, Netzwerk, Desktop-Prototyp

Stand: 20.11.2026. Alle Nachweise stammen aus QEMU mit KVM im CI, letzter voller Lauf:
https://github.com/MagieGubi/Veyra-OS/actions/runs/44810135273 (alle 16 Jobs grün, Commit 9b1f235).
**Auf echter Hardware ist 0.6 nie gestartet worden.**

## Neu

- **Sicherheit:** Firewall mit nftables (eingehend und Weiterleiten verworfen), Kernel-Härtung
  (19 sysctl-Werte, Yama), LLMNR und mDNS aus. Paket `veyra-firewall`, Doku `security.md`.
- **VPKG 0.6:** Quellen mit Spiegeln (`repos.d`), Paket-Cache, `update`, `search`, `clean`,
  `repo list`, Gruppen und Metapakete (`veyra-base`, `-network`, `-security`, `-development`,
  `-recovery`).
- **Boot:** systemd-boot ist jetzt Standard, mit Boot-Zähler. `veyra-kernel-update` trägt
  neue Kernel ein, und nach drei Fehlstarts startet automatisch wieder der alte Kernel.
- **Recovery:** `veyra-recovery` in der Live-ISO (liste, pruefe, repariere, kernel, logs).
- **Netzwerk:** `veyra-network`, `veyra-hwinfo`, iwd 3.12 und wireless-regdb. Dazu
  Intel-WLAN-Firmware für AX201, AX210 und AX211 (nur im Testabbild und im Repository).
- **Desktop-Prototyp (experimentell):** `veyra-desktop` startet cage mit kitty unter Wayland.
  Mesa 26.3.1 ohne LLVM, Darstellung nur in Software. Doku `desktop.md`.
- Kernel 6.18.56-veyra6.

## Bekannte Grenzen

- Kein Intel-Treiber iris (braucht LLVM, kommt mit 0.8), keine Hardware-Beschleunigung.
- WLAN, Intel-Grafik und Firmware sind auf echter Hardware nie geprüft.
- Kein PAM und kein sudo. Kein dauerhaftes Online-Paket-Repository; die Pakete liegen als
  CI-Artefakt bereit (7 Tage).

## Behobene Fehler seit 0.5.0 (Auswahl)

- vpkg ist beim Auspacken Symlinks auf Verzeichnisse gefolgt und hat dabei die Rechte des
  Ziels geändert, also auch außerhalb des Pakets.
- Herunterfahren hing an der Login-Shell (bereits in 0.5.0 behoben, bleibt getestet).
