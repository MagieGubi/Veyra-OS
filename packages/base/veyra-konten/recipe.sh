# Konten fuer Veyra: Ersteinrichtung des Testabbilds (root-Passwort, erster Benutzer).
# Im Testabbild ist root gesperrt und /etc/veyra/einrichtung-noetig vorhanden; dann
# startet veyra-einrichtung an Konsole 1 (tty1), und die Anmeldung dort ist bis zum
# Abschluss gesperrt. Im Entwicklungsabbild fehlt die Datei, das Paket tut dort nichts.
# veyra-kontencheck prueft Konten und Rechte passend zur Variante (Selbsttest, Installer).
# Beide Programme liegen neben diesem Rezept; bei jeder Aenderung daran muss sha256sums
# angepasst werden (tests/konten/konten-test.sh prueft das).
pkgname=veyra-konten
pkgver=0.3
pkgrel=1
pkgdesc="Ersteinrichtung: root-Passwort und erster Benutzer"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
sources=(veyra-einrichtung veyra-kontencheck)
sha256sums=(9534d233439587131f4ce5bf943958d4b98f20f921d34f42cb9eb598f3b19b6b db3a350f6d0131e545095590eb4bcb226b14fbf47776768fafd5b57aa99ac375)
depends=(shadow openssl bash systemd)

package() {
  install -Dm755 "$srcdir/veyra-einrichtung" "$pkgdir/usr/bin/veyra-einrichtung"
  install -Dm755 "$srcdir/veyra-kontencheck" "$pkgdir/usr/bin/veyra-kontencheck"
  install -d "$pkgdir/usr/lib/systemd/system/multi-user.target.wants" \
    "$pkgdir/usr/lib/systemd/system/getty@tty1.service.d"
  cat > "$pkgdir/usr/lib/systemd/system/veyra-einrichtung.service" <<'UNIT'
[Unit]
Description=Veyra-Ersteinrichtung (root-Passwort und erster Benutzer) an Konsole 1
ConditionPathExists=/etc/veyra/einrichtung-noetig
After=systemd-user-sessions.service systemd-vconsole-setup.service
Before=getty@tty1.service

[Service]
# simple statt oneshot: der Start des Systems wartet nicht auf die Eingabe.
Type=simple
ExecStart=/usr/bin/veyra-einrichtung
Restart=on-failure
RestartSec=2
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
UNIT
  cat > "$pkgdir/usr/lib/systemd/system/getty@tty1.service.d/50-veyra-einrichtung.conf" <<'CONF'
# Waehrend der Ersteinrichtung gehoert Konsole 1 dem Einrichtungsdialog.
[Unit]
ConditionPathExists=!/etc/veyra/einrichtung-noetig
CONF
  # Ohne PAM gibt es keine logind-Sitzung: die Login-Shell laeuft im getty-Dienst selbst
  # (login ersetzt sich durch die Shell). Eine interaktive bash ignoriert SIGTERM, und so
  # wartete das Herunterfahren nach einer Anmeldung bis zu 90 s auf SIGKILL (CI-Laeufe
  # 44054508868 und 44169569286). SIGHUP beendet die Shell sofort; spaetestens nach 5 s
  # wird sie beendet, wie es logind mit einer Sitzung auch taete.
  for u in getty@ serial-getty@; do
    install -d "$pkgdir/usr/lib/systemd/system/$u.service.d"
    cat > "$pkgdir/usr/lib/systemd/system/$u.service.d/60-veyra-stopp.conf" <<'CONF'
# Login-Shells duerfen das Herunterfahren nicht aufhalten (siehe veyra-konten).
[Service]
SendSIGHUP=yes
TimeoutStopSec=5s
CONF
  done
  ln -s ../veyra-einrichtung.service \
    "$pkgdir/usr/lib/systemd/system/multi-user.target.wants/veyra-einrichtung.service"
}
