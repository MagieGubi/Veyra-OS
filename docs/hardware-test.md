# Test auf echter Hardware (Phase 6)

Erstes Zielgerät: MSI Katana 15 B13VFK (Intel Core i7-13620H, 32 GB RAM, Intel UHD Graphics
und NVIDIA GeForce RTX 4060 Laptop, NVMe Micron 2400 1 TB mit Windows 11).

Veyra startet vom USB-Stick. Die interne SSD und Windows werden dabei nicht verändert:
der Selbsttest liest von der NVMe-SSD nur (Lesegeschwindigkeit), er schreibt nichts darauf.

## Was das Abbild dafür mitbringt

- Kernel mit Treibern für NVMe, USB-Sticks (xHCI, UAS), Intel-Grafik (i915), Bild über den
  UEFI-Framebuffer ab Kernelstart, eingebaute Tastatur, Touchpad, Intel-WLAN-Treiber
  (`kernel/config/veyra-30-hardware.config`).
- `rootwait` in der Kernel-Kommandozeile: der Kernel wartet, bis sich der USB-Stick meldet.
- Partition 3 `VEYRA-DATEN` (FAT): nach jedem Start legt der Selbsttest dort
  `veyra-messung.txt` (Ergebnis und Messwerte) und `kernel-log.txt` (dmesg) ab.
  Windows zeigt die Partition als normales Laufwerk.

Noch nicht dabei: Firmware-Dateien (ohne sie bleiben WLAN und manche Stromsparfunktionen der
Intel-Grafik aus) und NVIDIA. Beides folgt mit eigenen Paketen.

## Ablauf

1. Abbild `veyra-core-0.1.img.zst` aus dem Artefakt `veyra-core-0.1` des letzten CI-Laufs
   herunterladen und entpacken (z. B. mit 7-Zip, das `.zst` kann).
2. Mit balenaEtcher oder Rufus (Modus „DD-Abbild“) auf einen USB-Stick mit mindestens
   8 GB schreiben. Alles auf dem Stick wird dabei gelöscht.
   Fragt Windows danach, ob ein Laufwerk formatiert werden soll: **Abbrechen** (das ist die
   ext4-Partition von Veyra, Windows kann sie nicht lesen).
3. Secure Boot im BIOS ausschalten (MSI: beim Start `Entf` drücken, Reiter „Security“).
   Der Veyra-Kernel ist nicht von Microsoft signiert und startet sonst nicht.
4. Stick einstecken, beim Start `F11` drücken (Bootmenü) und den USB-Stick wählen.
5. Anmelden als `root` ohne Passwort. Etwa 20 s nach dem Start läuft der Selbsttest und
   zeigt seine Ergebnisse auf dem Bildschirm.
6. Mit `poweroff` ausschalten, Windows starten, im Laufwerk `VEYRA-DATEN` die Dateien
   `veyra-messung.txt` und `kernel-log.txt` öffnen.
7. Secure Boot im BIOS wieder einschalten, falls gewünscht (Windows 11 braucht es nicht
   zum Starten, manche Spiele mit Anti-Cheat schon).
