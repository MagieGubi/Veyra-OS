#!/bin/bash
# Stufe 4a, Teil 1 (in chroot): Verzeichnisbaum und grundlegende Dateien (LFS 12.4, Kapitel 7.5/7.6).
set -euo pipefail
mkdir -p /{boot,home,mnt,opt,srv}
mkdir -p /etc/{opt,sysconfig}
mkdir -p /lib/firmware
mkdir -p /media/{floppy,cdrom}
mkdir -p /usr/{,local/}{include,src}
mkdir -p /usr/lib/locale
mkdir -p /usr/local/{bin,lib,sbin}
mkdir -p /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -p /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -p /usr/{,local/}share/man/man{1..8}
mkdir -p /var/{cache,local,log,mail,opt,spool}
mkdir -p /var/lib/{color,misc,locate}
ln -sfn /run /var/run
ln -sfn /run/lock /var/lock
install -d -m 0750 /root
install -d -m 1777 /tmp /var/tmp

ln -sf /proc/self/mounts /etc/mtab
cat > /etc/hosts <<HOSTS
127.0.0.1  localhost veyra
::1        localhost
HOSTS

# Systemnutzer und -gruppen; weitere legt systemd-sysusers spaeter selbst an.
cat > /etc/passwd <<PASSWD
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
PASSWD
cat > /etc/group <<GROUP
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
GROUP
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp utmp /var/log/lastlog
chmod 664 /var/log/lastlog
chmod 600 /var/log/btmp
echo "Verzeichnisbaum und Grunddateien angelegt."
