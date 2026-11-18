# Firmware fuer Intel-WLAN (iwlwifi, Wi-Fi 6/6E) aus linux-firmware, Stand 20261019.
# Jede Datei ist einzeln gepinnt (Tag und SHA-256), geholt vom offiziellen Spiegel des
# linux-firmware-Repositorys auf gitlab.com. Ins Paket kommen die Lizenz und ein Auszug aus
# WHENCE mit genau den enthaltenen Dateien.
#
# Enthalten (je die neueste Firmware, die Linux 6.18 laedt, API 89):
#   so-a0-gf-a0  AX211 (CNVi in Intel Core 12. bis 14. Generation, Wi-Fi 6E)
#   so-a0-hr-b0  AX201 (CNVi in Intel Core 12. bis 14. Generation, Wi-Fi 6)
#   ty-a0-gf-a0  AX210 (PCIe- und M.2-Karte, Wi-Fi 6E)
# Welcher Chip eingebaut ist, zeigt veyra-hwinfo. Der Treiber (iwlwifi, iwlmvm) ist ein
# Kernelmodul und laedt die Firmware erst nach dem Einhaengen der Root-Partition.
_tag=20261019
_raw=https://gitlab.com/kernel-firmware/linux-firmware/-/raw/$_tag
pkgname=veyra-firmware-intel-wlan
pkgver=$_tag
pkgrel=1
pkgdesc="Firmware fuer Intel-WLAN AX201, AX210, AX211 (iwlwifi)"
license=LicenseRef-LICENCE.iwlwifi_firmware
url=https://gitlab.com/kernel-firmware/linux-firmware
groups=(veyra-firmware)
sources=($_raw/intel/iwlwifi/iwlwifi-so-a0-gf-a0-89.ucode
         $_raw/intel/iwlwifi/iwlwifi-so-a0-gf-a0.pnvm
         $_raw/intel/iwlwifi/iwlwifi-so-a0-hr-b0-89.ucode
         $_raw/intel/iwlwifi/iwlwifi-ty-a0-gf-a0-89.ucode
         $_raw/intel/iwlwifi/iwlwifi-ty-a0-gf-a0.pnvm
         $_raw/LICENSES/LICENCE.iwlwifi_firmware
         $_raw/WHENCE)
sha256sums=(fae8230ebd1426dfb7d5b5594fdd89e346af5144080659d010b8d2a2fd2f7d4a
            78abe08cf33bc209b96a887c7e3db8855a1d9650edacf849c4fa0d4596bcfac5
            6c4a1b2b4720865ee954a055b5aac19377187b142e1b7c5567524c61445bde20
            792478ef7752595525379a5068e2d47e310a2c344636b7df866c54746ced1dc0
            9697e327f8171454b3c19b1ec9449753d5b934d4e91722f469616818a6d477b0
            16d5040c7cf851fc693b7542e20870935b99802533ea1bfd231c377a2305e5c5
            0dd59e46f1e5d33d112236b17cb6de9d8f46fbf8fd09685cb474eb70a55f4da1)
_dateien=(iwlwifi-so-a0-gf-a0-89.ucode iwlwifi-so-a0-gf-a0.pnvm iwlwifi-so-a0-hr-b0-89.ucode
          iwlwifi-ty-a0-gf-a0-89.ucode iwlwifi-ty-a0-gf-a0.pnvm)

package() {
  local fw=$pkgdir/usr/lib/firmware doc=$pkgdir/usr/share/licenses/$pkgname f
  install -d "$fw/intel/iwlwifi" "$doc"
  for f in "${_dateien[@]}"; do
    # Jede Datei muss in WHENCE stehen und unter der iwlwifi-Lizenz verteilt werden.
    awk -v f="File: intel/iwlwifi/$f" '$0 == f {gefunden = 1} gefunden && /^Licen[cs]e:/ {print; exit}' \
      "$srcdir/WHENCE" | grep -q 'LICENCE.iwlwifi_firmware' \
      || { echo "$f: nicht unter LICENCE.iwlwifi_firmware in WHENCE" >&2; return 1; }
    install -m644 "$srcdir/$f" "$fw/intel/iwlwifi/$f"
    # Wie in WHENCE ("Link:"): der Treiber fragt nach dem Namen ohne Verzeichnis.
    ln -s "intel/iwlwifi/$f" "$fw/$f"
  done
  install -m644 "$srcdir/LICENCE.iwlwifi_firmware" "$doc/LICENCE.iwlwifi_firmware"
  {
    echo "Auszug aus WHENCE von linux-firmware $_tag ($url), nur die Dateien dieses Pakets:"
    echo
    for f in "${_dateien[@]}"; do
      awk -v f="File: intel/iwlwifi/$f" '$0 == f {p = 1} p && /^$/ {exit} p' "$srcdir/WHENCE"
      echo
    done
    grep -m1 -x 'Licence: Redistributable. See LICENCE.iwlwifi_firmware for details' "$srcdir/WHENCE"
  } > "$doc/WHENCE"
}
