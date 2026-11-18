"""veyra_fat: schreibt ein neues FAT32-Dateisystem mit wenigen Dateien (EFI-Systempartition).

Das Veyra-Basissystem enthaelt kein mkfs.fat (dosfstools). Fuer die EFI-Systempartition
genuegt ein FAT32 mit einer Handvoll Dateien, z. B. EFI/BOOT/BOOTX64.EFI und die
Booteintraege von systemd-boot. Dieses Modul legt so ein Dateisystem an einer Stelle einer
Datei oder eines Blockgeraets an (Partition per Versatz), ohne etwas einzuhaengen.
Namen, die keine kurzen 8.3-Namen in Grossbuchstaben sind (loader/entries/veyra-...conf),
bekommen lange Namen (VFAT) und einen erzeugten kurzen Namen (NAME~1.EXT).

Grenzen (bewusst): ein Cluster je Verzeichnis (128 Eintraege einschliesslich der langen
Namen), alle Dateien werden beim Anlegen geschrieben (kein Aendern danach). Geprueft wird mit fsck.fat und mtools
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
_VERBOTEN = set('"*/:<>?\\|') | {chr(i) for i in range(32)}


class FatFehler(Exception):
    pass


def _kurzname(teil):
    if not _NAME_RE.match(teil):
        raise FatFehler(f"kein gueltiger kurzer FAT-Name (8.3, Grossbuchstaben): {teil!r}")
    name, _, ext = teil.partition(".")
    return name.ljust(8).encode("ascii") + ext.ljust(3).encode("ascii")


def _pruefe_name(teil):
    if teil in (".", "..") or len(teil) > 255 or any(c in _VERBOTEN for c in teil) \
            or teil != teil.strip(" ."):
        raise FatFehler(f"ungueltiger Name auf FAT: {teil!r}")


def _pruefsumme(name11):
    s = 0
    for b in name11:
        s = (((s & 1) << 7) + (s >> 1) + b) & 0xFF
    return s


def _lange_eintraege(name, name11):
    """VFAT-Eintraege fuer den langen Namen NAME, in der Reihenfolge auf dem Datentraeger."""
    zeichen = list(name.encode("utf-16-le"))
    einheiten = [zeichen[i:i + 2] for i in range(0, len(zeichen), 2)]
    if len(einheiten) % 13:
        einheiten.append([0, 0])
        while len(einheiten) % 13:
            einheiten.append([0xFF, 0xFF])
    teile = [einheiten[i:i + 13] for i in range(0, len(einheiten), 13)]
    summe = _pruefsumme(name11)
    out = []
    for nr, teil in enumerate(teile, 1):
        b = bytes(x for e in teil for x in e)
        ordnung = nr | (0x40 if nr == len(teile) else 0)
        out.append(struct.pack("<B10sBBB12sH4s", ordnung, b[0:10], 0x0F, 0, summe, b[10:22], 0,
                               b[22:26]))
    return list(reversed(out))


def _namen(namen):
    """{langer Name: (name11, [VFAT-Eintraege])} fuer die Namen eines Verzeichnisses."""
    out, vergeben, klein = {}, set(), set()
    for n in sorted(namen):
        if n.upper() in klein:
            raise FatFehler(f"Namen unterscheiden sich nur in Gross-/Kleinschreibung: {n!r}")
        klein.add(n.upper())
    for n in sorted(namen):
        if _NAME_RE.match(n):
            out[n] = (_kurzname(n), [])
            vergeben.add(out[n][0])
    for n in sorted(namen):
        if n in out:
            continue
        _pruefe_name(n)
        basis, punkt, ext = n.rpartition(".")
        if not punkt:
            basis, ext = n, ""
        rein = lambda t: "".join(c for c in t.upper() if c.isascii() and (c.isalnum() or c in "_-"))
        basis, ext = rein(basis) or "DATEI", rein(ext)[:3]
        for i in range(1, 1000):
            zahl = f"~{i}"
            k = (basis[:8 - len(zahl)] + zahl).ljust(8).encode("ascii") + ext.ljust(3).encode("ascii")
            if k not in vergeben:
                break
        else:
            raise FatFehler(f"kein kurzer Name frei fuer {n!r}")
        vergeben.add(k)
        out[n] = (k, _lange_eintraege(n, k))
    return out


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

    # Baum aufbauen: {Name: (dict | bytes)}
    baum = {}
    for pfad, inhalt in sorted(dateien.items()):
        teile = [t for t in pfad.split("/") if t]
        if not teile:
            raise FatFehler(f"leerer Pfad: {pfad!r}")
        knoten = baum
        for t in teile[:-1]:
            knoten = knoten.setdefault(t, {})
            if not isinstance(knoten, dict):
                raise FatFehler(f"{t} ist Datei und Verzeichnis zugleich")
        k = teile[-1]
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
        namen = _namen(knoten)
        if 2 + sum(1 + len(lang) for _, lang in namen.values()) > CLUSTER // 32:
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
        for name, inhalt in sorted(knoten.items(), key=lambda x: namen[x[0]][0]):
            name11, lang = namen[name]
            eintraege.extend(lang)
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
