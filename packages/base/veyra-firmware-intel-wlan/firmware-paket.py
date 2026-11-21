#!/usr/bin/env python3
"""Gemeinsamer Paketschritt der Firmware-Pakete von Veyra (0.7).

Installiert die Firmware-Dateien eines Pakets aus linux-firmware nach /usr/lib/firmware und
prueft dabei, dass jede Datei in WHENCE steht und unter der angegebenen Lizenz verteilt wird.
Verweise (WHENCE "Link:"), die auf eine Datei des Pakets zeigen, werden angelegt. Ins Paket
kommen ausserdem die Lizenz, ein Auszug aus WHENCE und eine Beschreibung
/usr/share/veyra/firmware/PAKET.json (Version, Quelle, Lizenz, Treiber, Hardware, SHA-256 je
Datei), die veyra-hwinfo firmware liest.

Aufruf im Rezept (package):
  python3 "$srcdir/firmware-paket.py" --paket NAME --version TAG --quelle URL --lizenz DATEI \\
      --treiber iwlwifi --hardware "Text" ... -- intel/iwlwifi/datei ...
"""
import argparse
import hashlib
import json
import os
import posixpath
import re
import shutil
import sys


def fehler(text):
    print(f"firmware-paket: {text}", file=sys.stderr)
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    for n in ("paket", "version", "quelle", "lizenz"):
        ap.add_argument(f"--{n}", required=True)
    ap.add_argument("--treiber", action="append", default=[])
    ap.add_argument("--hardware", action="append", default=[])
    ap.add_argument("--srcdir", default=os.environ.get("srcdir", "."))
    ap.add_argument("--pkgdir", default=os.environ.get("pkgdir"))
    ap.add_argument("dateien", nargs="+")
    a = ap.parse_args()
    if not a.pkgdir:
        fehler("pkgdir fehlt")
    whence = open(os.path.join(a.srcdir, "WHENCE"), encoding="utf-8").read().splitlines()
    fw = os.path.join(a.pkgdir, "usr/lib/firmware")
    lizenz = os.path.basename(a.lizenz)
    unsere = set(a.dateien)
    auszug, eintraege = [], []
    for f in a.dateien:
        try:
            i = whence.index(f"File: {f}")
        except ValueError:
            fehler(f"{f} steht nicht in WHENCE")
        lz = next((z for z in whence[i:] if re.match(r"^Licen[cs]e:", z)), "")
        if lizenz not in lz:
            fehler(f"{f}: in WHENCE nicht unter {lizenz} ({lz or 'keine Lizenzzeile'})")
        quelle = os.path.join(a.srcdir, os.path.basename(f))
        ziel = os.path.join(fw, f)
        os.makedirs(os.path.dirname(ziel), exist_ok=True)
        shutil.copyfile(quelle, ziel)
        os.chmod(ziel, 0o644)
        with open(ziel, "rb") as h:
            eintraege.append({"pfad": f, "sha256": hashlib.sha256(h.read()).hexdigest()})
        auszug.append(f"File: {f}")
        auszug.extend(z for z in whence[i + 1:i + 4] if z.startswith("Version:"))
    links = []
    for z in whence:
        m = re.match(r"^Link: (\S+) -> (\S+)$", z)
        if m and posixpath.normpath(posixpath.join(posixpath.dirname(m.group(1)), m.group(2))) in unsere:
            pfad = os.path.join(fw, m.group(1))
            os.makedirs(os.path.dirname(pfad), exist_ok=True)
            os.symlink(m.group(2), pfad)
            links.append({"pfad": m.group(1), "ziel": m.group(2)})
            auszug.append(z)
    doc = os.path.join(a.pkgdir, "usr/share/licenses", a.paket)
    os.makedirs(doc, exist_ok=True)
    shutil.copyfile(os.path.join(a.srcdir, lizenz), os.path.join(doc, lizenz))
    with open(os.path.join(doc, "WHENCE"), "w") as h:
        h.write(f"Auszug aus WHENCE von linux-firmware {a.version} ({a.quelle}), nur die Dateien "
                f"dieses Pakets:\n\n" + "\n".join(auszug) + f"\n\nLizenz: {lizenz}\n")
    meta = os.path.join(a.pkgdir, "usr/share/veyra/firmware", a.paket + ".json")
    os.makedirs(os.path.dirname(meta), exist_ok=True)
    with open(meta, "w") as h:
        json.dump({"format": 1, "paket": a.paket, "version": a.version, "quelle": a.quelle,
                   "lizenz": lizenz, "treiber": a.treiber, "hardware": a.hardware,
                   "dateien": eintraege, "links": links}, h, indent=1, ensure_ascii=False)
        h.write("\n")
    print(f"firmware-paket: {a.paket}: {len(eintraege)} Dateien, {len(links)} Verweise")


if __name__ == "__main__":
    main()
