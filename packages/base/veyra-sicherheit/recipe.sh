# Sicherheits-Grundeinstellungen fuer Veyra (0.6, Phase 2): Kernel-Parameter per sysctl.
# Jede Zeile in 50-veyra-sicherheit.conf hat ihre Begruendung; eigene Werte gehoeren nach
# /etc/sysctl.d/ (gleicher Dateiname ersetzt diese Datei, hoehere Nummern gewinnen).
# Der Selbsttest prueft die Werte im laufenden System.
pkgname=veyra-sicherheit
pkgver=0.2
pkgrel=2
pkgdesc="Sicherheits-Grundeinstellungen (sysctl)"
license=MIT
url=https://github.com/MagieGubi/Veyra-OS
groups=(veyra-security)
depends=(systemd procps-ng)

package() {
  install -d "$pkgdir/usr/lib/sysctl.d"
  cat > "$pkgdir/usr/lib/sysctl.d/50-veyra-sicherheit.conf" <<'SYS'
# Veyra: Sicherheits-Grundeinstellungen (Paket veyra-sicherheit)
# Kernel-Adressen auch fuer root in /proc verbergen (erschwert Exploits)
kernel.kptr_restrict = 2
# Kernel-Log nur fuer root lesbar
kernel.dmesg_restrict = 1
# ptrace nur auf eigene Kindprozesse (Yama)
kernel.yama.ptrace_scope = 1
# BPF nur fuer root (der Kernel hat keinen BPF-JIT, net.core.bpf_jit_harden entfaellt)
kernel.unprivileged_bpf_disabled = 1
# Kein Kernelwechsel im laufenden Betrieb per kexec
kernel.kexec_load_disabled = 1
# Keine Speicherabbilder von Programmen mit erhoehten Rechten
fs.suid_dumpable = 0
# Schutz vor Angriffen ueber Links, FIFOs und Dateien in fremden, allgemein beschreibbaren Verzeichnissen
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
# Netz: keine ICMP-Umleitungen annehmen oder senden, kein Source-Routing, SYN-Cookies
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
SYS
}
