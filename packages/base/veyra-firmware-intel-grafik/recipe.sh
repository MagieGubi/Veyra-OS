# Firmware fuer Intel-Grafik (i915) der Core-Prozessoren der 12. bis 14. Generation (Alder
# Lake, Raptor Lake) aus linux-firmware, Stand 20261019; je Datei gepinnt wie
# veyra-firmware-intel-wlan. Ohne sie laeuft i915 trotzdem, aber ohne Energiesparzustaende
# des Bildschirms (DMC) und ohne GuC/HuC (Zeitplanung auf der GPU, Video-Beschleunigung).
#   adlp_dmc, adlp_guc_70, tgl_huc   Notebooks (Alder Lake-P/H, Raptor Lake-P/H/U)
#   adls_dmc_ver2_01, tgl_guc_70     Desktop (Alder Lake-S, Raptor Lake-S)
_tag=20261019
_raw=https://gitlab.com/kernel-firmware/linux-firmware/-/raw/$_tag
pkgname=veyra-firmware-intel-grafik
pkgver=$_tag
pkgrel=1
pkgdesc="Firmware fuer Intel-Grafik (i915) der 12. bis 14. Core-Generation"
license=LicenseRef-LICENSE.i915
url=https://gitlab.com/kernel-firmware/linux-firmware
groups=(veyra-firmware)
_dateien=(i915/adlp_dmc.bin i915/adlp_guc_70.bin i915/tgl_huc.bin i915/adls_dmc_ver2_01.bin
          i915/tgl_guc_70.bin)
sources=(${_dateien[@]/#/$_raw/}
         $_raw/LICENSES/LICENSE.i915
         $_raw/WHENCE
         firmware-paket.py)
sha256sums=(3516de2e134ddcf3b319c75d2e437779fecbd58cbb77234bd6f297c544e92ccb
            b7a800cbdcdf687e7b1c81f3316d040ab75fa3e5c698ebc356f077af17462ef8
            dbb1316bac13a76427ffa7827e52b5b9affe8a4cadd23dc22e2a54e35c53bdad
            96e426ed7e80f0cc6644ada1928f4d02b163ff59b14b2339aa28a374d65a5b19
            2f1f57a1b23d186f2592318d1e07a1365968932841ccb3e7177c516ba006e2f6
            8542aeabf2761935122d693561e16766ce1bcc2b0d003204f9040b7d6d929f2e
            0dd59e46f1e5d33d112236b17cb6de9d8f46fbf8fd09685cb474eb70a55f4da1
            7e4d16c2170dcda7f58bb462de4f428f2501515b3b0171dca6e037ac4834ef0c)

package() {
  python3 "$srcdir/firmware-paket.py" --paket "$pkgname" --version "$_tag" --quelle "$url" \
    --lizenz LICENSE.i915 --treiber i915 \
    --hardware "Intel UHD/Iris Xe Graphics, Core 12. bis 14. Generation" -- "${_dateien[@]}"
}
