#!/usr/bin/env python3
"""fetch-gomod.py: laedt die Go-Module aus einer go.sum in ein Verzeichnis im Format eines
Go-Modul-Proxys (GOPROXY=file://ZIEL), damit ein Bau ohne Netz (chroot) sie findet.

Aufruf: fetch-gomod.py GO.SUM ZIEL [PROXY]   (PROXY: https://proxy.golang.org)

Geprueft wird hier nichts: Go selbst vergleicht beim Bau jede .mod- und .zip-Datei mit dem
h1-Hash in go.sum (GOSUMDB=off schaltet nur die Abfrage der Pruefsummen-Datenbank ab, nicht
den Vergleich mit go.sum). go.sum stammt aus dem signierten Quellarchiv.
"""
import json
import os
import sys
import time
import urllib.request


def escape(pfad):
    """Modulpfad wie im Proxy-Protokoll: Grossbuchstaben als !kleinbuchstabe."""
    return "".join("!" + c.lower() if c.isupper() else c for c in pfad)


def lade(url, ziel):
    if os.path.exists(ziel):
        return
    os.makedirs(os.path.dirname(ziel), exist_ok=True)
    for versuch in range(4):
        try:
            with urllib.request.urlopen(url, timeout=120) as r, open(ziel + ".teil", "wb") as f:
                f.write(r.read())
            os.replace(ziel + ".teil", ziel)
            return
        except OSError as e:
            if versuch == 3:
                raise SystemExit(f"fetch-gomod: {url}: {e}")
            time.sleep(5 * (versuch + 1))


def main():
    if len(sys.argv) not in (3, 4):
        print(__doc__)
        return 2
    gosum, ziel = sys.argv[1:3]
    proxy = (sys.argv[3] if len(sys.argv) == 4 else "https://proxy.golang.org").rstrip("/")
    mods, zips = set(), set()
    with open(gosum) as f:
        for zeile in f:
            teile = zeile.split()
            if len(teile) != 3:
                continue
            mod, ver = teile[0], teile[1]
            if ver.endswith("/go.mod"):
                mods.add((mod, ver[:-len("/go.mod")]))
            else:
                zips.add((mod, ver))
                mods.add((mod, ver))
    for mod, ver in sorted(mods):
        basis = f"{escape(mod)}/@v/{escape(ver)}"
        lade(f"{proxy}/{basis}.mod", os.path.join(ziel, basis + ".mod"))
        info = os.path.join(ziel, basis + ".info")
        if not os.path.exists(info):
            with open(info, "w") as f:
                json.dump({"Version": ver}, f)
    for mod, ver in sorted(zips):
        basis = f"{escape(mod)}/@v/{escape(ver)}"
        lade(f"{proxy}/{basis}.zip", os.path.join(ziel, basis + ".zip"))
    print(f"fetch-gomod: {len(mods)} Module (.mod), {len(zips)} Archive (.zip) in {ziel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
