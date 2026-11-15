"""veyra_fat: schreibt ein neues FAT32-Dateisystem mit wenigen Dateien (EFI-Systempartition).

Das Veyra-Basissystem enthaelt kein mkfs.fat (dosfstools). Fuer die EFI-Systempartition
genuegt ein FAT32 mit einer Handvoll Dateien in kurzen Namen (8.3, Grossbuchstaben),
z. B. EFI/BOOT/BOOTX64.EFI. Dieses Modul legt so ein Dateisystem an einer Stelle einer
Datei oder eines Blockgeraets an (Partition per Versatz), ohne etwas einzuhaengen.

Grenzen (bewusst): nur kurze Namen, hoechstens 126 Eintraege je Verzeichnis, alle Dateien
werden beim Anlegen geschrieben (kein Aendern danach). Geprueft wird mit fsck.fat und mtools
(tests/installer/installer-test.sh).
"""

import os
import re
import struct
import time

SEKTOR = 512
SEKTOREN_JE_CLUSTER = 8          # 4 KiB je Cluster
CLUSTER = SEKTOR * SEKTOREN_JE_CLUSTER
RESERVIERT = 32                  # reservierte Sektoren (Bootsektor, FSInfo, Sicherung)
ENDE = 0x0FFFFFFF                # Ende einer Clusterkette
MIN_CLUSTER = 65525              # weniger Cluster waeren nach Spezifikation FAT16

_NAME_RE = re.compile(r"^[A-Z0-9_-]{1,8}(\.[A-Z0-9_-]{1,3})?$")


class FatFehler(Exception):
    pass


def _kurzname(teil):
    if not _NAME_RE.match(teil):
        raise FatFehler(f"kein gueltiger kurzer FAT-Name (8.3, Grossbuchstaben): {teil!r}")
    name, _, ext = teil.partition(".")
    return name.ljust(8).encode("ascii") + ext.ljust(3).encode("ascii")


def _fat_datum(epoch):
    t = time.gmtime(max(epoch, 315532800))  # FAT kennt nichts vor 1980
    datum = ((t.tm_year - 1980) << 9) | (t.tm_mon << 5) | t.tm_mday
    zeit = (t.tm_hour << 11) | (t.tm_min << 5) | (t.tm_sec // 2)
    return datum, zeit


def _eintrag(name11, attr, cluster, groesse, datum, zeit):
    return struct.pack("<11sBBBHHHHHHHI", name11, attr, 0, 0, zeit, datum, datum,
                       cluster >> 16, zeit, datum, cluster & 0xFFFF, groesse)


def geometrie(groesse):
    """Sektoren gesamt, Sektoren je FAT und Zahl der Datencluster fuer GROESSE Bytes."""
    gesamt = groesse // SEKTOR
    fat = 1
    while True:
        cluster = (gesamt - RESERVIERT - 2 * fat) // SEKTOREN_JE_CLUSTER
        noetig = -(-((cluster + 2) * 4) // SEKTOR)
        if noetig <= fat:
            break
        fat = noetig
    if cluster < MIN_CLUSTER:
        raise FatFehler(f"Partition zu klein fuer FAT32: {groesse} Bytes "
                        f"(mindestens {(MIN_CLUSTER * CLUSTER) >> 20} MiB)")
    return gesamt, fat, cluster


def schreibe_fat32(ziel, versatz, groesse, dateien, bezeichnung="VEYRA-EFI",
                   vol_id=None, start_lba=None, epoch=None):
    """Legt in ZIEL (Pfad) ab VERSATZ ein FAT32 der Groesse GROESSE an.

    DATEIEN: {"EFI/BOOT/BOOTX64.EFI": bytes, ...}; Verzeichnisse entstehen von selbst.
    Gibt die Zahl der belegten Cluster zurueck.
    """
    if versatz % SEKTOR or groesse % SEKTOR:
        raise FatFehler("Versatz und Groesse muessen Vielfache von 512 sein")
    gesamt, fat_sek, clusterzahl = geometrie(groesse)
    if epoch is None:
        epoch = int(os.environ.get("SOURCE_DATE_EPOCH", "1767225600"))
    datum, zeit = _fat_datum(epoch)
    if vol_id is None:
        vol_id = int.from_bytes(os.urandom(4), "little")
    if start_lba is None:
        start_lba = versatz // SEKTOR

    # Baum aufbauen: {name11: (dict | bytes)}
    baum = {}
    for pfad, inhalt in sorted(dateien.items()):
        teile = [t for t in pfad.split("/") if t]
        if not teile:
            raise FatFehler(f"leerer Pfad: {pfad!r}")
        knoten = baum
        for t in teile[:-1]:
            k = _kurzname(t)
            knoten = knoten.setdefault(k, {})
            if not isinstance(knoten, dict):
                raise FatFehler(f"{t} ist Datei und Verzeichnis zugleich")
        k = _kurzname(teile[-1])
        if k in knoten:
            raise FatFehler(f"doppelter Eintrag: {pfad}")
        knoten[k] = bytes(inhalt)

    # Cluster vergeben (zusammenhaengend, ab Cluster 2 = Wurzelverzeichnis).
    fat = {0: 0x0FFFFFF8, 1: ENDE}
    daten = {}  # erster Cluster -> bytes
    naechster = [2]

    def belege(laenge):
        n = max(1, -(-laenge // CLUSTER))
        erster = naechster[0]
        if erster + n - 2 > clusterzahl:
            raise FatFehler("Partition zu klein fuer die Dateien")
        for c in range(erster, erster + n - 1):
            fat[c] = c + 1
        fat[erster + n - 1] = ENDE
        naechster[0] += n
        return erster

    def verzeichnis(knoten, eigener, eltern, wurzel):
        if len(knoten) > 126:
            raise FatFehler("zu viele Eintraege in einem Verzeichnis")
        eintraege = []
        if wurzel:  # Wurzel: Datentraegerbezeichnung zuerst
            eigener = belege(CLUSTER)
            eintraege.append(_eintrag(bezeichnung.upper().ljust(11)[:11].encode("ascii"),
                                      0x08, 0, 0, datum, zeit))
        else:
            eintraege.append(_eintrag(b".          ", 0x10, eigener, 0, datum, zeit))
            eintraege.append(_eintrag(b"..         ", 0x10, eltern, 0, datum, zeit))
        unter = []
        for name11, inhalt in sorted(knoten.items()):
            if isinstance(inhalt, dict):
                c = belege(CLUSTER)
                eintraege.append(_eintrag(name11, 0x10, c, 0, datum, zeit))
                unter.append((inhalt, c))
            else:
                c = belege(len(inhalt)) if inhalt else 0
                eintraege.append(_eintrag(name11, 0x20, c, len(inhalt), datum, zeit))
                if inhalt:
                    daten[c] = inhalt
        daten[eigener] = b"".join(eintraege).ljust(CLUSTER, b"\0")
        # ".." zeigt auf 0, wenn die Eltern die Wurzel sind (so verlangt es FAT).
        for inhalt, c in unter:
            verzeichnis(inhalt, c, 0 if wurzel else eigener, False)

    verzeichnis(baum, None, 0, True)
    belegt = naechster[0] - 2
    frei = clusterzahl - belegt

    # Bootsektor
    bs = bytearray(SEKTOR)
    bs[0:3] = b"\xEB\x58\x90"
    bs[3:11] = b"VEYRA   "
    struct.pack_into("<HBHBHHBHHHII", bs, 11, SEKTOR, SEKTOREN_JE_CLUSTER, RESERVIERT, 2,
                     0, 0, 0xF8, 0, 32, 64, start_lba, gesamt)
    struct.pack_into("<IHHIHH", bs, 36, fat_sek, 0, 0, 2, 1, 6)
    struct.pack_into("<BBBI", bs, 64, 0x80, 0, 0x29, vol_id)
    bs[71:82] = bezeichnung.upper().ljust(11)[:11].encode("ascii")
    bs[82:90] = b"FAT32   "
    bs[510:512] = b"\x55\xAA"
    fsinfo = bytearray(SEKTOR)
    struct.pack_into("<I", fsinfo, 0, 0x41615252)
    struct.pack_into("<III", fsinfo, 484, 0x61417272, frei, naechster[0])
    struct.pack_into("<I", fsinfo, 508, 0xAA550000)

    reserviert = bytearray(RESERVIERT * SEKTOR)
    reserviert[0:SEKTOR] = bs
    reserviert[SEKTOR:2 * SEKTOR] = fsinfo
    reserviert[6 * SEKTOR:7 * SEKTOR] = bs
    reserviert[7 * SEKTOR:8 * SEKTOR] = fsinfo

    fat_tab = bytearray(fat_sek * SEKTOR)
    for c, wert in fat.items():
        struct.pack_into("<I", fat_tab, c * 4, wert)

    daten_start = versatz + (RESERVIERT + 2 * fat_sek) * SEKTOR
    fd = os.open(ziel, os.O_WRONLY)
    try:
        def schreibe(pos, b):
            os.lseek(fd, pos, os.SEEK_SET)
            mv = memoryview(b)
            while mv:
                n = os.write(fd, mv)
                mv = mv[n:]
        schreibe(versatz, reserviert)
        schreibe(versatz + RESERVIERT * SEKTOR, fat_tab)
        schreibe(versatz + (RESERVIERT + fat_sek) * SEKTOR, fat_tab)
        for c, b in sorted(daten.items()):
            schreibe(daten_start + (c - 2) * CLUSTER, b)
        os.fsync(fd)
    finally:
        os.close(fd)
    return belegt
