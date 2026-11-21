# Firmware fuer Intel-Bluetooth (btusb mit btintel) aus linux-firmware, Stand 20261019; je
# Datei gepinnt wie veyra-firmware-intel-wlan. Intel-WLAN-Karten haben Bluetooth auf demselben
# Chip; welche Datei der Kernel laedt (ibt-CNVI-CNVR), haengt von der Kombination aus Chipsatz
# und Funkteil ab und steht nach dem Start im Kernel-Log ("Found device firmware:"). Enthalten
# sind die Kombinationen fuer Core 12. bis 14. Generation, Core Ultra und AX210/AX211/BE200;
# veyra-hwinfo firmware meldet, wenn der Kernel eine Datei vermisst.
_tag=20261019
_raw=https://gitlab.com/kernel-firmware/linux-firmware/-/raw/$_tag
pkgname=veyra-firmware-intel-bluetooth
pkgver=$_tag
pkgrel=1
pkgdesc="Firmware fuer Intel-Bluetooth (AX201, AX210, AX211 und Nachfolger)"
license=LicenseRef-LICENCE.ibt_firmware
url=https://gitlab.com/kernel-firmware/linux-firmware
groups=(veyra-firmware)
_dateien=(intel/ibt-0040-0041.ddc intel/ibt-0040-0041.sfi intel/ibt-0040-1020.ddc
          intel/ibt-0040-1020.sfi intel/ibt-0041-0041.ddc intel/ibt-0041-0041.sfi
          intel/ibt-0093-0041.ddc intel/ibt-0093-0041.sfi intel/ibt-0093-0291.ddc
          intel/ibt-0093-0291.sfi intel/ibt-0093-1050.ddc intel/ibt-0093-1050.sfi
          intel/ibt-0093-4150.ddc intel/ibt-0093-4150.sfi intel/ibt-0180-0041.ddc
          intel/ibt-0180-0041.sfi intel/ibt-0180-1050.ddc intel/ibt-0180-1050.sfi
          intel/ibt-0180-4150.ddc intel/ibt-0180-4150.sfi)
sources=(${_dateien[@]/#/$_raw/}
         $_raw/LICENSES/LICENCE.ibt_firmware
         $_raw/WHENCE
         firmware-paket.py)
sha256sums=(fe272982577efdc289cfe3e8bedafca607c0b7d6c9df1aab1880e22ef930d077
            f14d059858623283f9e1bca3c9f5c5edc272cf538959d8f194327e3a9af5a75a
            fe272982577efdc289cfe3e8bedafca607c0b7d6c9df1aab1880e22ef930d077
            609b00758870c7f10141221f73c3798c336305df1d312ced4f6de4ed9624491f
            fe272982577efdc289cfe3e8bedafca607c0b7d6c9df1aab1880e22ef930d077
            2e5f11ecc302e10dba51e9e07babef1b6d5c2a2359c695f1a23836552271d906
            e0fb10fe29f60607d6507ced3f697492d9611f62c4765feaee59c4bd4101d3e7
            20e1cf592e1d97a1691ba1ed7b0b5d88595c9801b82287764f132bad79941bf6
            e0fb10fe29f60607d6507ced3f697492d9611f62c4765feaee59c4bd4101d3e7
            2b4671c49992845877541e0d780bff77ea6f6a02134b5503d1b4531367397f0f
            e0fb10fe29f60607d6507ced3f697492d9611f62c4765feaee59c4bd4101d3e7
            20e1cf592e1d97a1691ba1ed7b0b5d88595c9801b82287764f132bad79941bf6
            e0fb10fe29f60607d6507ced3f697492d9611f62c4765feaee59c4bd4101d3e7
            20e1cf592e1d97a1691ba1ed7b0b5d88595c9801b82287764f132bad79941bf6
            fe272982577efdc289cfe3e8bedafca607c0b7d6c9df1aab1880e22ef930d077
            0e925583b92c63915fb38246d2ef312a0c3152f18a97a3ab914fda0555848fc7
            fe272982577efdc289cfe3e8bedafca607c0b7d6c9df1aab1880e22ef930d077
            0e925583b92c63915fb38246d2ef312a0c3152f18a97a3ab914fda0555848fc7
            fe272982577efdc289cfe3e8bedafca607c0b7d6c9df1aab1880e22ef930d077
            0e925583b92c63915fb38246d2ef312a0c3152f18a97a3ab914fda0555848fc7
            5181b0b51efc79d5acb2c9bb92042878fdbad97a92114d4ab5e32e2b5b52fce4
            0dd59e46f1e5d33d112236b17cb6de9d8f46fbf8fd09685cb474eb70a55f4da1
            7e4d16c2170dcda7f58bb462de4f428f2501515b3b0171dca6e037ac4834ef0c)

package() {
  python3 "$srcdir/firmware-paket.py" --paket "$pkgname" --version "$_tag" --quelle "$url" \
    --lizenz LICENCE.ibt_firmware --treiber btintel \
    --hardware "Intel Bluetooth (AX201, AX210, AX211, BE200)" -- "${_dateien[@]}"
}
