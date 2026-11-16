"""Baut dist/Friendsmith-<Version>.zip zum Testen oder fuer den manuellen Upload auf CurseForge.

Aufruf (im Addon-Ordner):  python tools/build_zip.py

- Nimmt nur, was ins Spiel gehoert (gleiche Ausnahmen wie .pkgmeta).
- Liegt ein Ordner Libs/ vor, kommen die Bibliotheken mit hinein.
  Sonst wird embeds.xml aus der .toc entfernt (der Button laeuft dann ueber
  Bibliotheken anderer Addons oder als eigener Minimap-Button).
"""
import os
import re
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAME = "Friendsmith"

SKIP_DIRS = {".git", ".github", "assets", "tools", "dist"}
SKIP_FILES = {".gitignore", ".pkgmeta", "CURSEFORGE.md", "RELEASE.md", os.path.join("Media", "logo128.tga")}


def main():
    toc_path = os.path.join(ROOT, NAME + ".toc")
    toc = open(toc_path, encoding="utf-8").read()
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    has_libs = os.path.isdir(os.path.join(ROOT, "Libs"))
    if not has_libs:
        toc = re.sub(r"#@no-lib-strip@.*?#@end-no-lib-strip@\n?", "", toc, flags=re.S)

    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    out = os.path.join(ROOT, "dist", f"{NAME}-{version}.zip")
    count = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for base, dirs, files in os.walk(ROOT):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
            for f in sorted(files):
                full = os.path.join(base, f)
                rel = os.path.relpath(full, ROOT)
                if rel in SKIP_FILES or (not has_libs and rel == "embeds.xml"):
                    continue
                arc = NAME + "/" + rel.replace(os.sep, "/")
                if rel == NAME + ".toc":
                    z.writestr(arc, toc)
                else:
                    z.write(full, arc)
                count += 1
    print(f"{out}  ({count} Dateien, Bibliotheken: {'ja' if has_libs else 'nein'})")


if __name__ == "__main__":
    main()
