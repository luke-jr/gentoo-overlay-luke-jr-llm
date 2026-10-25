#!/usr/bin/env python3
"""Check that the build made again every checked-in generated file the ebuild moved aside.

src_prepare moves the tarball's generated files to ${WORKDIR}/upstream-generated (see
chromium_regenerated_outputs in the ebuild). After src_compile, each should exist in the tree
again. Lists how many came back (and how many are identical to the checked-in copy), how many
were in directories the unbundling removed, and every one that is missing.

Usage: verify-regenerated.py WORKDIR   (e.g. /var/tmp/portage/www-client/chromium-157.0.8103.15/work)
"""
import collections
import filecmp
import glob
import os
import sys

if len(sys.argv) != 2:
    sys.exit(__doc__)
work = sys.argv[1]
moved = os.path.join(work, "upstream-generated")
trees = [d for d in glob.glob(os.path.join(work, "chromium-*")) if os.path.isdir(os.path.join(d, "chrome"))]
if not os.path.isdir(moved) or len(trees) != 1:
    sys.exit(f"{work}: no upstream-generated/ or not exactly one chromium-* tree")
tree = trees[0]
missing, unbundled, same, differ = [], [], 0, 0
for d, _, files in os.walk(moved):
    for f in files:
        rel = os.path.relpath(os.path.join(d, f), moved)
        t = os.path.join(tree, rel)
        if os.path.lexists(t):
            if filecmp.cmp(os.path.join(d, f), t, shallow=False):
                same += 1
            else:
                differ += 1
        elif not os.path.isdir(os.path.dirname(t)) or not os.listdir(os.path.dirname(t)):
            unbundled.append(rel)
        else:
            missing.append(rel)
print(f"made again: {same + differ} ({same} identical to the checked-in copy, {differ} different)")
print(f"in directories the unbundling emptied or removed: {len(unbundled)}")
for k, v in sorted(collections.Counter(os.path.dirname(f) for f in unbundled).items()):
    print("   ", v, k)
print(f"NOT made again: {len(missing)}")
for f in sorted(missing):
    print("   ", f)
