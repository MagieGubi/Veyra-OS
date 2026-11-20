"""veyra_install: Logik des Veyra-Installers, getrennt von der Oberflaeche (veyra-install).

Ablauf einer Installation (installiere):
  1. Ziel untersuchen (untersuche): ganzer Datentraeger oder Abbild-Datei, nicht
     eingehaengt, nicht in Benutzung, traegt nicht das Startmedium, gross genug, keine
     zweite Partition veyra-root auf einem anderen Datentraeger. Vorhandene
     Partitionen und erkannte Systeme werden gemeldet; ueberschrieben wird nur, wenn
     die Oberflaeche die Bestaetigung (Geraetename) eingeholt hat.
  2. GPT schreiben: 1  EFI-Systempartition (512 MiB, FAT32), 2  Root (ext4,
     Partitionsname veyra-root, Rest der Platte). Bootweg (ab 0.6):
     - systemd-boot (Standard): \\EFI\\BOOT\\BOOTX64.EFI ist systemd-boot, der Kernel liegt
       unter /veyra/VERSION/linux, der Eintrag loader/entries/veyra-VERSION+3.conf findet
       Root ueber root=PARTUUID=... und zaehlt Startversuche (Rueckfall, siehe
       docs/recovery.md); erst ein vollstaendiger Start macht den Eintrag dauerhaft.
     - direkt (Rueckfallweg aus 0.5): der Kernel selbst ist BOOTX64.EFI und findet Root
       ueber root=PARTLABEL=veyra-root (eingebaute Kommandozeile).
  3. Root-Dateisystem anlegen, das Quellsystem hineinkopieren (in der Live-ISO das
     unveraenderte SquashFS unter /run/veyra-live/sfs) und als installiertes System
     einrichten: root gesperrt bis zur Ersteinrichtung an Konsole 1, su nur fuer wheel,
     eigene machine-id beim ersten Start, Selbsttest entfernt.
  4. Pruefen: vpkg check (Pakete vollstaendig) und veyra-kontencheck (Konten, Rechte).

Partitionen werden ueber ihren Versatz angesprochen (Loop-Geraet mit --offset), nicht
ueber /dev/sdX1: das funktioniert gleich fuer echte Datentraeger und Abbild-Dateien und
braucht kein udev.
"""

import glob
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile

import veyra_fat

MIB = 1 << 20
START_MIB = 1                 # Beginn der ersten Partition (Ausrichtung)
ESP_MIB = 512                 # EFI-Systempartition
RESERVE_MIB = 1024            # freier Platz im Root zusaetzlich zum System
ROOT_NAME = "veyra-root"      # Partitionsname, den die Kernel-Kommandozeile erwartet
ESP_NAME = "veyra-efi"
ESP_TYP = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
LIVE_QUELLE = "/run/veyra-live/sfs"
KERNEL_MUSTER = "usr/lib/modules/*/vmlinuz"
SD_BOOT = "usr/lib/systemd/boot/efi/systemd-bootx64.efi"
BOOTWEGE = ("systemd-boot", "direkt")
BOOT_VERSUCHE = 3             # Startversuche, bevor systemd-boot einen Eintrag als schlecht gilt

# Partitionstypen, an denen ein vorhandenes System erkennbar ist (GPT-Typ-GUID).
TYPEN = {
    ESP_TYP: "EFI-Systempartition",
    "E3C9E316-0B5C-4DB8-817D-F92DF00215AE": "Microsoft reserviert (Windows)",
    "DE94BBA4-06D1-4D40-A16A-BFD50179D6AC": "Windows-Wiederherstellung",
    "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7": "Windows-Daten (Basic Data)",
    "0FC63DAF-8483-4772-8E79-3D69D8477DE4": "Linux-Dateisystem",
    "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F": "Linux-Swap",
    "4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709": "Linux-Root (x86-64)",
}


class InstallFehler(Exception):
    pass


def lauf(cmd, eingabe=None):
    """Fuehrt CMD aus; bei Fehler InstallFehler mit der Fehlermeldung des Programms."""
    try:
        r = subprocess.run(cmd, input=eingabe, text=True, capture_output=True)
    except FileNotFoundError:
        raise InstallFehler(f"Programm fehlt: {cmd[0]}") from None
    if r.returncode != 0:
        raise InstallFehler(f"{' '.join(cmd)} fehlgeschlagen: "
                            f"{(r.stderr or r.stdout).strip()}")
    return r.stdout


def mib(n):
    return f"{n / MIB:.0f} MiB" if n < 10 * 1024 * MIB else f"{n / (1024 * MIB):.1f} GiB"


# ---------------------------------------------------------------- Datentraeger

def datentraeger():
    """Alle Datentraeger (lsblk), je mit Partitionen, Dateisystemen und Einhaengepunkten."""
    out = lauf(["lsblk", "-J", "-b", "-o",
                "NAME,PATH,SIZE,TYPE,MODEL,TRAN,RM,RO,MOUNTPOINTS,FSTYPE,LABEL,PARTLABEL,PTTYPE"])
    liste = []
    for d in json.loads(out).get("blockdevices", []):
        if d.get("type") not in ("disk", "loop") or not int(d.get("size") or 0):
            continue
        liste.append(d)
    return liste


def _sysname(pfad):
    return os.path.basename(os.path.realpath(pfad))


def _majmin_zu_datentraeger(majmin):
    """'8:1' -> Name des ganzen Datentraegers ('sda'), ueber /sys/dev/block."""
    p = f"/sys/dev/block/{majmin}"
    if not os.path.exists(p):
        return None
    p = os.path.realpath(p)
    if os.path.exists(os.path.join(p, "partition")):
        p = os.path.dirname(p)
    return os.path.basename(p)


def _traeger_von(pfad, tiefe=0):
    """Namen der Datentraeger, auf denen PFAD liegt (folgt Loop-Geraeten zur Datei)."""
    try:
        st = os.stat(pfad)
    except OSError:
        return set()
    if os.major(st.st_dev) == 0 or tiefe > 5:
        return set()
    name = _majmin_zu_datentraeger(f"{os.major(st.st_dev)}:{os.minor(st.st_dev)}")
    if not name:
        return set()
    namen = {name}
    backing = f"/sys/block/{name}/loop/backing_file"
    if os.path.exists(backing):
        with open(backing) as f:
            namen |= _traeger_von(f.read().strip(), tiefe + 1)
    return namen


def _eingehaengte_geraete():
    """major:minor aller eingehaengten Dateisysteme und aktiven Swap-Bereiche."""
    belegt = set()
    with open("/proc/self/mountinfo") as f:
        for z in f:
            belegt.add(z.split()[2])
    try:
        with open("/proc/swaps") as f:
            for z in list(f)[1:]:
                try:
                    st = os.stat(z.split()[0])
                    if stat.S_ISBLK(st.st_mode):
                        belegt.add(f"{os.major(st.st_rdev)}:{os.minor(st.st_rdev)}")
                except OSError:
                    pass
    except OSError:
        pass
    return belegt


def _partitionen(ziel):
    """Vorhandene Partitionen laut Partitionstabelle (leer, wenn keine da ist)."""
    r = subprocess.run(["sfdisk", "-J", ziel], text=True, capture_output=True)
    if r.returncode != 0 or not r.stdout.strip():
        return None, []
    t = json.loads(r.stdout)["partitiontable"]
    sek = int(t.get("sectorsize", 512))
    teile = []
    for p in t.get("partitions", []):
        teile.append({"start": int(p["start"]) * sek, "groesse": int(p["size"]) * sek,
                      "typ": str(p.get("type", "")).upper(), "name": p.get("name", "")})
    return t.get("label"), teile


def _blkid(ziel, versatz=0):
    """Dateisystem an einer Stelle des Ziels (blkid ohne Cache, direkt gelesen)."""
    r = subprocess.run(["blkid", "-p", "-o", "export", "-O", str(versatz), ziel],
                       text=True, capture_output=True)
    werte = {}
    for z in r.stdout.splitlines():
        k, _, v = z.partition("=")
        werte[k] = v
    return werte


def erkenne_system(teil, fs):
    """Kurze Beschreibung, was auf einer Partition liegt."""
    typ = fs.get("TYPE", "")
    if teil.get("name") == ROOT_NAME or fs.get("PART_ENTRY_NAME") == ROOT_NAME:
        return "Veyra OS"
    if typ == "ntfs":
        return "Windows (NTFS)"
    if typ == "crypto_LUKS":
        return "verschluesselt (LUKS)"
    if typ == "BitLocker":
        return "verschluesselt (BitLocker)"
    if typ in ("ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs"):
        return f"Linux ({typ})"
    if typ == "swap":
        return "Linux-Swap"
    if typ in ("vfat", "exfat"):
        return "EFI-Systempartition" if teil.get("typ") == ESP_TYP else f"Daten ({typ})"
    return TYPEN.get(teil.get("typ", ""), "unbekannt")


def quellgroesse(quelle):
    """Belegter Platz des Quellsystems in Bytes (ohne andere Dateisysteme)."""
    out = lauf(["du", "-sxb", quelle])
    return int(out.split()[0])


def mindestgroesse(belegt):
    root = int(belegt * 1.15) + RESERVE_MIB * MIB
    return (START_MIB + ESP_MIB) * MIB + root + MIB


def untersuche(ziel, quelle=None):
    """Prueft ZIEL. Ergebnis: dict mit art, groesse, partitionen (mit erkannten Systemen),
    hindernisse (Installation unmoeglich) und mindestgroesse."""
    info = {"ziel": ziel, "hindernisse": [], "partitionen": [], "tabelle": None,
            "groesse": 0, "art": None, "mindestgroesse": None, "modell": "",
            "lesbar": True}
    h = info["hindernisse"]
    try:
        st = os.stat(ziel)
    except OSError as e:
        h.append(f"{ziel} nicht gefunden ({e.strerror})")
        return info
    if stat.S_ISBLK(st.st_mode):
        info["art"] = "datentraeger"
        name = _sysname(ziel)
        sysd = f"/sys/class/block/{name}"
        if os.path.exists(f"{sysd}/partition"):
            h.append(f"{ziel} ist eine Partition; bitte den ganzen Datentraeger angeben")
            return info
        with open(f"{sysd}/size") as f:
            info["groesse"] = int(f.read()) * 512
        with open(f"{sysd}/ro") as f:
            if f.read().strip() == "1":
                h.append(f"{ziel} ist schreibgeschuetzt")
        try:
            with open(f"{sysd}/queue/logical_block_size") as f:
                if int(f.read()) != 512:
                    h.append(f"{ziel} hat 4K-Sektoren; das kann der Installer noch nicht")
        except OSError:
            pass
        try:
            with open(f"{sysd}/device/model") as f:
                info["modell"] = f.read().strip()
        except OSError:
            pass
        eigene = {f"{os.major(st.st_rdev)}:{os.minor(st.st_rdev)}"}
        for p in glob.glob(f"{sysd}/{name}*/dev"):
            with open(p) as f:
                eigene.add(f.read().strip())
        if eigene & _eingehaengte_geraete():
            h.append(f"{ziel} oder eine seiner Partitionen ist eingehaengt oder als Swap aktiv")
        benutzt = [os.path.basename(x) for x in glob.glob(f"{sysd}/holders/*")
                   + glob.glob(f"{sysd}/{name}*/holders/*")]
        if benutzt:
            h.append(f"{ziel} wird benutzt von {', '.join(benutzt)} (LVM, RAID oder Verschluesselung)")
        if quelle and name in _traeger_von(quelle):
            h.append(f"{ziel} traegt das Quellsystem (Startmedium); darauf kann nicht installiert werden")
        if quelle and name in _traeger_von("/run/veyra-live/medium"):
            h.append(f"{ziel} ist das Startmedium der Live-ISO")
    elif stat.S_ISREG(st.st_mode):
        info["art"] = "datei"
        info["groesse"] = st.st_size
        echt = os.path.realpath(ziel)
        for b in glob.glob("/sys/block/loop*/loop/backing_file"):
            with open(b) as f:
                if f.read().strip() == echt:
                    h.append(f"{ziel} ist schon an {b.split('/')[3]} gebunden (in Benutzung)")
    else:
        h.append(f"{ziel} ist weder ein Datentraeger noch eine Abbild-Datei")
        return info

    try:
        fd = os.open(ziel, os.O_RDONLY)
        try:
            os.read(fd, 4096)
        finally:
            os.close(fd)
    except OSError as e:
        h.append(f"{ziel} ist nicht lesbar ({e.strerror}); vorhandene Daten nicht pruefbar")
        info["lesbar"] = False
        return info

    info["tabelle"], teile = _partitionen(ziel)
    for t in teile:
        fs = _blkid(ziel, t["start"])
        t["dateisystem"] = fs.get("TYPE", "")
        t["bezeichnung"] = fs.get("LABEL", "")
        t["system"] = erkenne_system(t, fs)
        info["partitionen"].append(t)
    if not teile:
        fs = _blkid(ziel)
        if fs.get("TYPE"):
            info["partitionen"].append({"start": 0, "groesse": info["groesse"], "typ": "",
                                        "name": "", "dateisystem": fs["TYPE"],
                                        "bezeichnung": fs.get("LABEL", ""),
                                        "system": erkenne_system({}, fs) + ", ohne Partitionstabelle"})

    # Eine zweite Partition veyra-root auf einem anderen Datentraeger wuerde der Kernel
    # beim Start ebenfalls finden; welches System dann startet, waere Zufall.
    if info["art"] == "datentraeger":
        try:
            for d in datentraeger():
                if d.get("name") == _sysname(ziel):
                    continue
                for k in d.get("children") or []:
                    if k.get("partlabel") == ROOT_NAME:
                        h.append(f"Auf {d.get('path')} gibt es schon eine Partition {ROOT_NAME} "
                                 f"({k.get('path')}); der Kernel koennte das falsche System starten")
        except (InstallFehler, ValueError):
            pass

    if quelle:
        info["mindestgroesse"] = mindestgroesse(quellgroesse(quelle))
        if info["groesse"] < info["mindestgroesse"]:
            h.append(f"{ziel} ist zu klein: {mib(info['groesse'])}, "
                     f"noetig sind mindestens {mib(info['mindestgroesse'])}")
    return info


# ---------------------------------------------------------------- Quelle

def finde_kernel(quelle):
    kerne = sorted(glob.glob(os.path.join(quelle, KERNEL_MUSTER)))
    if len(kerne) != 1:
        raise InstallFehler(f"im Quellsystem muss genau ein Kernel liegen ({KERNEL_MUSTER}), "
                            f"gefunden: {len(kerne)}")
    return kerne[0]


def pruefe_quelle(quelle, bootweg="systemd-boot"):
    if bootweg not in BOOTWEGE:
        raise InstallFehler(f"unbekannter Bootweg {bootweg!r} (erlaubt: {', '.join(BOOTWEGE)})")
    noetig = ["usr/lib/systemd/systemd", "usr/bin/vpkg", "usr/bin/veyra-einrichtung",
              "usr/bin/veyra-kontencheck", "etc/shadow", "var/lib/vpkg"]
    if bootweg == "systemd-boot":
        noetig.append(SD_BOOT)
    fehlt = [p for p in noetig if not os.path.exists(os.path.join(quelle, p))]
    if fehlt:
        raise InstallFehler(f"{quelle} ist kein vollstaendiges Veyra-System, es fehlt: "
                            + ", ".join("/" + p for p in fehlt))
    return finde_kernel(quelle)


# ---------------------------------------------------------------- Plan

def plan(info):
    """Die Partitionen, die angelegt werden (Byte-Angaben)."""
    esp_start = START_MIB * MIB
    root_start = esp_start + ESP_MIB * MIB
    root_groesse = (info["groesse"] // MIB - START_MIB - ESP_MIB - 1) * MIB
    return [
        {"nr": 1, "name": ESP_NAME, "typ": "EFI-Systempartition (FAT32)",
         "start": esp_start, "groesse": ESP_MIB * MIB},
        {"nr": 2, "name": ROOT_NAME, "typ": "Veyra-Root (ext4)",
         "start": root_start, "groesse": root_groesse},
    ]


# ---------------------------------------------------------------- Einrichten

def _setze_zeile(pfad, schluessel, zeile):
    """Ersetzt in PFAD die (auch auskommentierte) Zeile SCHLUESSEL oder haengt ZEILE an."""
    with open(pfad) as f:
        zeilen = f.read().splitlines()
    neu, gefunden = [], False
    for z in zeilen:
        if z.lstrip("#").strip().split(" ")[0].split("\t")[0] == schluessel:
            if not gefunden:
                neu.append(zeile)
            gefunden = True
        else:
            neu.append(z)
    if not gefunden:
        neu.append(zeile)
    with open(pfad, "w") as f:
        f.write("\n".join(neu) + "\n")


def richte_ein(root, hostname="veyra", melde=print):
    """Macht aus einer Kopie des Quellsystems ein installiertes System."""
    etc = os.path.join(root, "etc")
    with open(os.path.join(etc, "fstab"), "w") as f:
        f.write("# Dateisystem          Ziel  Typ   Optionen  dump  fsck\n"
                f"PARTLABEL={ROOT_NAME}   /     ext4  defaults  1     1\n"
                "# EFI-Systempartition: beim ersten Zugriff einhaengen (systemd-bless-boot,\n"
                "# veyra-kernel-update), nach 60 s ohne Zugriff wieder aushaengen:\n"
                f"PARTLABEL={ESP_NAME}    /efi  vfat  "
                "noauto,x-systemd.automount,x-systemd.idle-timeout=60,nofail,umask=0077  0  2\n")
    os.makedirs(os.path.join(root, "efi"), mode=0o700, exist_ok=True)
    with open(os.path.join(etc, "hostname"), "w") as f:
        f.write(hostname + "\n")
    # Leere machine-id: das System erzeugt beim ersten Start seine eigene.
    open(os.path.join(etc, "machine-id"), "w").close()
    os.makedirs(os.path.join(etc, "veyra"), exist_ok=True)
    with open(os.path.join(etc, "veyra", "variante"), "w") as f:
        f.write("system\n")
    # root sperren, Konten ohne Passwort sperren (sollte es keine geben).
    sp = os.path.join(etc, "shadow")
    with open(sp) as f:
        zeilen = f.read().splitlines()
    for i, z in enumerate(zeilen):
        teile = z.split(":")
        if len(teile) < 2:
            continue
        if teile[0] == "root":
            teile[1] = "!*"
        elif teile[1] == "":
            teile[1] = "!"
            melde(f"Konto {teile[0]} hatte kein Passwort, jetzt gesperrt")
        zeilen[i] = ":".join(teile)
    st = os.stat(sp)
    with open(sp, "w") as f:
        f.write("\n".join(zeilen) + "\n")
    os.chmod(sp, stat.S_IMODE(st.st_mode))
    open(os.path.join(etc, "veyra", "einrichtung-noetig"), "w").close()
    fertig = os.path.join(root, "var/lib/veyra/einrichtung-fertig")
    if os.path.exists(fertig):
        os.remove(fertig)
    _setze_zeile(os.path.join(etc, "login.defs"), "SU_WHEEL_ONLY", "SU_WHEEL_ONLY yes")
    with open(os.path.join(etc, "issue"), "w") as f:
        f.write("Veyra OS 0.6 \\l\n"
                "Beim ersten Start fragt die Ersteinrichtung an Konsole 1 nach dem root-Passwort.\n\n")
    # Reste der Live-ISO (Einhaengepunkte des Startmediums) entfernen.
    for d in glob.glob(os.path.join(etc, "systemd/system/run-veyra\\x2dlive-*.mount.d")):
        shutil.rmtree(d)


def entferne_selbsttest(root, vpkg, melde=print):
    db = os.path.join(root, "var/lib/vpkg/installed")
    if os.path.isdir(os.path.join(db, "veyra-selftest")):
        melde("Selbsttest entfernen (vpkg remove veyra-selftest)")
        lauf([sys.executable, vpkg, "--root", root, "remove", "veyra-selftest"])
    shutil.rmtree(os.path.join(root, "usr/lib/veyra/selftest"), ignore_errors=True)


# ---------------------------------------------------------------- Installation

def _sichere_tabelle(ziel, groesse):
    """Liest Anfang und Ende des Ziels (je 1 MiB: MBR, GPT und Sicherungs-GPT)."""
    fd = os.open(ziel, os.O_RDONLY)
    try:
        anfang = os.pread(fd, MIB, 0)
        ende = os.pread(fd, MIB, groesse - MIB)
    finally:
        os.close(fd)
    return anfang, ende


def _stelle_tabelle_her(ziel, groesse, sicherung):
    anfang, ende = sicherung
    fd = os.open(ziel, os.O_WRONLY)
    try:
        os.pwrite(fd, anfang, 0)
        os.pwrite(fd, ende, groesse - MIB)
        os.fsync(fd)
    finally:
        os.close(fd)
    subprocess.run(["blockdev", "--rereadpt", ziel], capture_output=True)


def esp_dateien(quelle, kernel, partuuid, bootweg):
    """Inhalt der EFI-Systempartition: {Pfad: bytes}."""
    with open(kernel, "rb") as f:
        k = f.read()
    if bootweg == "direkt":
        return {"EFI/BOOT/BOOTX64.EFI": k}
    with open(os.path.join(quelle, SD_BOOT), "rb") as f:
        sdb = f.read()
    kver = os.path.basename(os.path.dirname(kernel))
    eintrag = (f"title      Veyra OS\n"
               f"version    {kver}\n"
               f"sort-key   veyra\n"
               f"linux      /veyra/{kver}/linux\n"
               f"options    root=PARTUUID={partuuid} rw\n")
    return {
        "EFI/BOOT/BOOTX64.EFI": sdb,
        "EFI/systemd/systemd-bootx64.efi": sdb,
        "loader/loader.conf": b"timeout 3\ndefault veyra-*\neditor no\n",
        f"veyra/{kver}/linux": k,
        f"loader/entries/veyra-{kver}+{BOOT_VERSUCHE}.conf": eintrag.encode(),
    }


def installiere(ziel, quelle, mit_selbsttest=False, hostname="veyra", melde=print, konten=None,
                bootweg="systemd-boot"):
    """Installiert QUELLE auf ZIEL. Die Bestaetigung muss die Oberflaeche vorher einholen.

    KONTEN: None (Ersteinrichtung beim ersten Start) oder eine Funktion konten(root), die
    im fertig kopierten System root-Passwort und Benutzer einrichtet.

    Bei einem Fehler vor dem Schreiben der ersten Partition stellt der Installer die alte
    Partitionstabelle wieder her (das Ziel ist dann unveraendert). Danach ist das nicht mehr
    moeglich: die Root-Partition heisst bis zum Schluss veyra-unfertig und startet nicht."""
    if os.geteuid() != 0:
        raise InstallFehler("der Installer braucht root")
    kernel = pruefe_quelle(quelle, bootweg)
    info = untersuche(ziel, quelle)
    if info["hindernisse"]:
        raise InstallFehler("Installation nicht moeglich:\n  " + "\n  ".join(info["hindernisse"]))
    teile = plan(info)
    esp, rootp = teile

    sicherung = _sichere_tabelle(ziel, info["groesse"])
    melde(f"Partitionstabelle (GPT) auf {ziel} schreiben")
    # Root zuerst unter anderem Namen anlegen: bricht die Installation ab, findet der
    # Kernel kein halbfertiges veyra-root.
    skript = ("label: gpt\n"
              f"start={esp['start'] // 512}, size={esp['groesse'] // 512}, type={ESP_TYP}, name=\"{ESP_NAME}\"\n"
              f"start={rootp['start'] // 512}, size={rootp['groesse'] // 512}, type=L, name=\"veyra-unfertig\"\n")
    try:
        lauf(["sfdisk", "-q", "--wipe", "always", ziel], skript)
        _, neu = _partitionen(ziel)
        if len(neu) != 2 or neu[0]["start"] != esp["start"] or neu[1]["start"] != rootp["start"]:
            raise InstallFehler("Partitionstabelle nach dem Schreiben nicht wie geplant")
        partuuid = lauf(["sfdisk", "--part-uuid", ziel, "2"]).strip().lower()
        if len(partuuid) != 36:
            raise InstallFehler(f"PARTUUID der Root-Partition nicht lesbar: {partuuid!r}")
    except (InstallFehler, OSError) as e:
        _stelle_tabelle_her(ziel, info["groesse"], sicherung)
        raise InstallFehler(f"{e}\nDie alte Partitionstabelle ist wiederhergestellt, "
                            "auf dem Ziel wurde nichts veraendert.") from e

    melde(f"EFI-Systempartition (FAT32) mit Kernel {os.path.basename(os.path.dirname(kernel))}, "
          f"Bootweg {bootweg}")
    veyra_fat.schreibe_fat32(ziel, esp["start"], esp["groesse"],
                             esp_dateien(quelle, kernel, partuuid, bootweg))

    loop = mnt = None
    try:
        loop = lauf(["losetup", "--find", "--show", "--offset", str(rootp["start"]),
                     "--sizelimit", str(rootp["groesse"]), ziel]).strip()
        melde("Root-Dateisystem (ext4) anlegen")
        lauf(["mkfs.ext4", "-q", "-F", "-L", ROOT_NAME, loop])
        mnt = tempfile.mkdtemp(prefix="veyra-ziel.")
        lauf(["mount", "-t", "ext4", loop, mnt])
        melde(f"System kopieren aus {quelle}")
        lauf(["cp", "-a", "--one-file-system", os.path.join(quelle, "."), mnt])
        melde("System einrichten (root gesperrt bis zur Ersteinrichtung)")
        richte_ein(mnt, hostname, melde)
        if konten is not None:
            melde("Konten einrichten (root-Passwort, Benutzer)")
            konten(mnt)
        vpkg = os.path.join(mnt, "usr/bin/vpkg")
        if not mit_selbsttest:
            entferne_selbsttest(mnt, vpkg, melde)
        melde("Pruefen: vpkg check")
        lauf([sys.executable, vpkg, "--root", mnt, "check"])
        melde("Pruefen: veyra-kontencheck")
        lauf(["bash", os.path.join(mnt, "usr/bin/veyra-kontencheck"), "--root", mnt])
        lauf(["sync"])
    finally:
        if mnt:
            subprocess.run(["umount", mnt], capture_output=True)
            os.rmdir(mnt)
        if loop:
            subprocess.run(["losetup", "-d", loop], capture_output=True)

    melde(f"Partition 2 in {ROOT_NAME} umbenennen (ab jetzt startbar)")
    lauf(["sfdisk", "-q", "--part-label", ziel, "2", ROOT_NAME])
    return teile
