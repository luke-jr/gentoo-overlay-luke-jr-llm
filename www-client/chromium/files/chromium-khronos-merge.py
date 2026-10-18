#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Install a header regenerated with a Khronos registry's genheaders.py over the
checked-in copy it replaces, keeping only what the regeneration can't reproduce:

- version stamps: the generation date ("Generated on date", *_EXT_VERSION) and
  the registry commit ("Khronos $Git commit"), where both sides differ only in them;
- ANGLE's additions: lines that include its own extension headers (*_angle.h).

Everything else comes from the regenerated header.

Usage: chromium-khronos-merge.py REGENERATED CHECKED_IN
"""
import difflib
import re
import sys

STAMP = re.compile(r"^(/\* Generated on date \d+ \*/|\*\* Khronos \$Git commit\$?.*"
                   r"|#define \w+_VERSION \d{8})\s*$")

new_path, dest_path = sys.argv[1:]
new = open(new_path).read().splitlines(keepends=True)
dest = open(dest_path).read().splitlines(keepends=True)

out = []
matcher = difflib.SequenceMatcher(a=new, b=dest, autojunk=False)
for op, i1, i2, j1, j2 in matcher.get_opcodes():
    if op == "equal":
        out += new[i1:i2]
    elif op == "replace" and i2 - i1 == j2 - j1:
        out += [d if STAMP.match(n) and STAMP.match(d) else n for n, d in zip(new[i1:i2], dest[j1:j2])]
    elif op == "insert" and any(re.match(r'#include "\w+_angle\.h"', l) for l in dest[j1:j2]):
        out += dest[j1:j2]
    elif op != "insert":
        out += new[i1:i2]
open(dest_path, "w").write("".join(out))
