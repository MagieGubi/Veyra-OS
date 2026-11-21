# Firmware fuer Intel-WLAN (iwlwifi, Wi-Fi 6/6E) aus linux-firmware, Stand 20261019.
# Jede Datei ist einzeln gepinnt (Tag und SHA-256), geholt vom offiziellen Spiegel des
# linux-firmware-Repositorys auf gitlab.com. Gemeinsamer Paketschritt aller Firmware-Pakete:
# firmware-paket.py (prueft WHENCE und Lizenz, legt die Verweise an, schreibt
# /usr/share/veyra/firmware/$pkgname.json fuer veyra-hwinfo firmware).
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
pkgrel=2
pkgdesc="Firmware fuer Intel-WLAN AX201, AX210, AX211 (iwlwifi)"
license=LicenseRef-LICENCE.iwlwifi_firmware
url=https://gitlab.com/kernel-firmware/linux-firmware
groups=(veyra-firmware)
_dateien=(intel/iwlwifi/iwlwifi-so-a0-gf-a0-89.ucode intel/iwlwifi/iwlwifi-so-a0-gf-a0.pnvm
          intel/iwlwifi/iwlwifi-so-a0-hr-b0-89.ucode intel/iwlwifi/iwlwifi-ty-a0-gf-a0-89.ucode
          intel/iwlwifi/iwlwifi-ty-a0-gf-a0.pnvm)
sources=(${_dateien[@]/#/$_raw/}
         $_raw/LICENSES/LICENCE.iwlwifi_firmware
         $_raw/WHENCE
         firmware-paket.py)
sha256sums=(fae8230ebd1426dfb7d5b5594fdd89e346af5144080659d010b8d2a2fd2f7d4a
            78abe08cf33bc209b96a887c7e3db8855a1d9650edacf849c4fa0d4596bcfac5
            6c4a1b2b4720865ee954a055b5aac19377187b142e1b7c5567524c61445bde20
            792478ef7752595525379a5068e2d47e310a2c344636b7df866c54746ced1dc0
            9697e327f8171454b3c19b1ec9449753d5b934d4e91722f469616818a6d477b0
            16d5040c7cf851fc693b7542e20870935b99802533ea1bfd231c377a2305e5c5
            0dd59e46f1e5d33d112236b17cb6de9d8f46fbf8fd09685cb474eb70a55f4da1
            7e4d16c2170dcda7f58bb462de4f428f2501515b3b0171dca6e037ac4834ef0c)

package() {
  python3 "$srcdir/firmware-paket.py" --paket "$pkgname" --version "$_tag" --quelle "$url" \
    --lizenz LICENCE.iwlwifi_firmware --treiber iwlwifi \
    --hardware "Intel Wi-Fi 6 AX201 (CNVi)" --hardware "Intel Wi-Fi 6E AX210" \
    --hardware "Intel Wi-Fi 6E AX211 (CNVi)" -- "${_dateien[@]}"
}
