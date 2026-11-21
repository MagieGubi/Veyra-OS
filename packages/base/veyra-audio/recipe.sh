# Ton fuer Veyra (0.7) und Metapaket der Gruppe @veyra-audio: PipeWire mit WirePlumber und
# PulseAudio-Schnittstelle als Systemdienste (Veyra hat kein PAM, also keine Benutzer-Sitzungen
# von systemd), ALSA-Programme ueber PipeWire, Werkzeug veyra-audio. Die Dateien liegen neben
# diesem Rezept; bei jeder Aenderung muss sha256sums angepasst werden
# (tests/audio/audio-test.sh prueft das).
pkgname=veyra-audio
pkgver=0.7
pkgrel=1
pkgdesc="Ton: PipeWire, WirePlumber, ALSA und veyra-audio (Metapaket)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-audio)
sources=(veyra-audio veyra-pipewire.service veyra-wireplumber.service veyra-pipewire-pulse.service pipewire-sysusers.conf 50-veyra.conf veyra-audio.sh)
sha256sums=(140471bae306f3307d84f6fdcfc5e0559a9721ec4eed68f664b974b61a651fb4 651cd4831f796d9c809a98bb1c1d96ec3b77f62837a939ebf8e1c7d1cd6b2f94 d6854bfbeabde33ea7ff8f64d4d73cda5c38269a89e1b8a92f78a0d908b8a459 a7482da02b801b7914d906d72e665c8c367bf87d85c18ff05a48b1d3fa5ca3aa 0b6ad02621e28493d4d2472c5daff5286849b0dc219b186b69b51a461f87096e fa183101ed236df290964e34a7d45a20bfc530a12865b8b73af919ba2081cc84 ac81f2a3e759425d46c07669da091ddc4c5e0b6e37db8b603fa474dd7f460e34)
depends=(python systemd pipewire wireplumber alsa-lib alsa-utils)

package() {
  install -Dm755 "$srcdir/veyra-audio" "$pkgdir/usr/bin/veyra-audio"
  for u in veyra-pipewire veyra-wireplumber veyra-pipewire-pulse; do
    install -Dm644 "$srcdir/$u.service" "$pkgdir/usr/lib/systemd/system/$u.service"
  done
  install -Dm644 "$srcdir/pipewire-sysusers.conf" "$pkgdir/usr/lib/sysusers.d/veyra-audio.conf"
  install -Dm644 "$srcdir/50-veyra.conf" "$pkgdir/usr/share/wireplumber/wireplumber.conf.d/50-veyra.conf"
  install -Dm644 "$srcdir/veyra-audio.sh" "$pkgdir/etc/profile.d/veyra-audio.sh"
  # ALSA-Programme (aplay, alles ohne eigene PipeWire-Unterstuetzung) ueber PipeWire
  install -d "$pkgdir/etc/alsa/conf.d"
  for f in 50-pipewire.conf 99-pipewire-default.conf; do
    ln -s "/usr/share/alsa/alsa.conf.d/$f" "$pkgdir/etc/alsa/conf.d/$f"
  done
}

post_install() {
  systemd-sysusers /usr/lib/sysusers.d/veyra-audio.conf
  systemctl enable veyra-pipewire.service veyra-wireplumber.service veyra-pipewire-pulse.service \
    >/dev/null 2>&1 || true
}

pre_remove() {
  systemctl disable veyra-pipewire.service veyra-wireplumber.service veyra-pipewire-pulse.service \
    >/dev/null 2>&1 || true
}
