#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Delete the npm packages in a Chromium source tree that the build doesn't use.

The tarball ships the node_modules directories of WebUI (third_party/node),
chromium-bidi and DevTools: build tools, type declarations and libraries, as
npm publishes them (mostly generated JavaScript). KEEP_LIST names the packages
the build uses (one path per line, relative to the tree; # starts a comment);
every other package directory under the node_modules directories those paths
are in is deleted, including packages nested in kept ones, and .bin.

Exit status 1 if a kept package doesn't exist (the list needs updating).

Usage: chromium-prune-node-modules.py TREE KEEP_LIST
"""

import os
import shutil
import sys


def main():
    tree, keep_list = sys.argv[1:]
    keep = set()
    for line in open(keep_list, encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if line:
            keep.add(line)
    missing = sorted(k for k in keep if not os.path.isdir(os.path.join(tree, k)))
    if missing:
        sys.exit("Kept npm packages not found:\n  " + "\n  ".join(missing))

    # Everything a kept package needs to stay: the package itself and the
    # packages it's nested in.
    needed = set()
    for k in keep:
        parts = k.split("/node_modules/")
        for i in range(2, len(parts) + 1):
            needed.add("/node_modules/".join(parts[:i]))
    roots = {k.split("/node_modules/")[0] + "/node_modules" for k in keep}

    removed = 0

    def remove(rel):
        nonlocal removed
        path = os.path.join(tree, rel)
        if os.path.islink(path):
            os.unlink(path)
        else:
            shutil.rmtree(path)
        removed += 1

    def prune(node_modules):
        for entry in sorted(os.listdir(os.path.join(tree, node_modules))):
            rel = f"{node_modules}/{entry}"
            path = os.path.join(tree, rel)
            if not os.path.isdir(path):
                continue  # e.g. .package-lock.json
            if entry.startswith("@") and not os.path.islink(path):
                for sub in sorted(os.listdir(path)):
                    prune_package(f"{rel}/{sub}")
                if not os.listdir(path):
                    os.rmdir(path)
            else:
                prune_package(rel)

    def prune_package(rel):
        if rel not in needed:
            remove(rel)
        elif os.path.isdir(os.path.join(tree, rel, "node_modules")):
            prune(f"{rel}/node_modules")

    for root in sorted(roots):
        prune(root)
    print(f"Removed {removed} npm packages, kept {len(keep)}")


if __name__ == "__main__":
    main()
