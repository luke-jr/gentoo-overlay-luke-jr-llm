#!/usr/bin/env python3
"""Compare an upgraded tree (the base tarball with the upgrade patches applied, nothing else)
with the real tarball of that version, once it is out, and sort the differences by the
filter's rules (filter.py), so that only the unexpected ones need a look.

Usage: compare-tarball.py TREE_DIR TARBALL
  TREE_DIR  the upgraded tree (e.g. a work directory after the upgrade patches only)
  TARBALL   the real tarball of the version the patches upgrade to

Prints one line per difference (changed, only in the tree, only in the tarball), with the
category: translation, test/docs/other platform, upstream profile, binary (unused), or
"UNEXPECTED". Every UNEXPECTED line is either a mistake of the patches to fix, or something
to add to the rules (and to README.md's notes).
"""
import hashlib
import os
import sys
import tarfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import filter as rules  # noqa: E402

GIT_EXCLUDED = (".git/",)


def category(f):
    if rules.TRANSLATION.search(f):
        return "translation"
    if rules.PROFILES.search(f) or f.startswith("chrome/build/pgo_profiles/"):
        return "upstream profile"
    if rules.IRRELEVANT.search(f) or rules.PLATFORM.search(f):
        return "test/docs/other platform"
    if f.startswith("third_party/icu/") and f.endswith((".dat", ".res")):
        return "binary (unused)"
    return "UNEXPECTED"


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for b in iter(lambda: fh.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    tree, tarball = sys.argv[1:3]
    seen = set()
    out = []
    with tarfile.open(tarball, "r|xz") as t:
        for m in t:
            if not (m.isfile() or m.issym()):
                continue
            f = m.name.split("/", 1)[1]
            seen.add(f)
            p = os.path.join(tree, f)
            if not os.path.lexists(p):
                out.append(("only in the tarball", f))
            elif m.issym():
                if not os.path.islink(p) or os.readlink(p) != m.linkname:
                    out.append(("changed", f))
            else:
                h = hashlib.sha256()
                fh = t.extractfile(m)
                for b in iter(lambda: fh.read(1 << 20), b""):
                    h.update(b)
                if os.path.islink(p) or digest(p) != h.hexdigest():
                    out.append(("changed", f))
    for dirpath, dirs, files in os.walk(tree):
        dirs[:] = [d for d in dirs if d != ".git"]
        for name in files:
            f = os.path.relpath(os.path.join(dirpath, name), tree)
            if f not in seen:
                out.append(("only in the tree", f))
    for kind, f in sorted(out, key=lambda x: (category(x[1]) != "UNEXPECTED", x[1])):
        print(f"{category(f)}\t{kind}\t{f}")


main()
