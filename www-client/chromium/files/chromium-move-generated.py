#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Move checked-in generated files out of the source tree, so that the build can only use the
regenerated ones (a regeneration step that doesn't write one makes the build fail).

Usage: chromium-move-generated.py SRC DEST [STAMP] < PATTERNS
  Moves the files of SRC that PATTERNS match to DEST, at the same relative paths. PATTERNS
  has one pattern per line, relative to SRC: '*' and '?' match within a path component,
  '**/' any number of directories, a trailing '/' everything below a directory; '!' before a
  pattern excludes what it matches from the earlier ones. Empty lines and lines starting with
  '#' are ignored. A pattern (or exclusion) that matches nothing is an error, so that a change
  upstream (a renamed or removed file) doesn't go unnoticed. Directories stay.
  With STAMP (a file made when the sources were unpacked), it is an error too if one of the
  files was changed since (by a patch): its regeneration would undo that change.
"""
import bisect
import os
import re
import sys


def regex(pattern):
    if pattern.endswith("/"):
        pattern += "**"
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pattern.startswith("**", i):
            out += ".*"
            i += 2
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        elif pattern[i] == "?":
            out += "[^/]"
            i += 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile(out + r"\Z")


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    src, dest = sys.argv[1:3]
    since = os.stat(sys.argv[3]).st_mtime if len(sys.argv) == 4 else None
    files = []
    for dirpath, dirs, names in os.walk(src):
        for name in names:
            files.append(os.path.relpath(os.path.join(dirpath, name), src))
    files.sort()
    selected, unmatched = {}, []
    for line in sys.stdin:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        exclude = line.startswith("!")
        pattern = line[1:] if exclude else line
        r = regex(pattern)
        # Only the files that start with the pattern's literal part can match.
        prefix = re.split(r"[*?]", pattern, maxsplit=1)[0]
        lo, hi = bisect.bisect_left(files, prefix), bisect.bisect_left(files, prefix + "\U0010ffff")
        matched = [f for f in files[lo:hi] if r.match(f)]
        if not matched:
            unmatched.append(line)
        for f in matched:
            if exclude:
                selected.pop(f, None)
            else:
                selected[f] = True
    if unmatched:
        sys.exit("These patterns of checked-in generated files match nothing:\n  " + "\n  ".join(unmatched))
    if since is not None:
        changed = [f for f in selected if os.lstat(os.path.join(src, f)).st_mtime > since]
        if changed:
            sys.exit("These checked-in generated files were changed after unpacking (by a patch?), which "
                     "their regeneration would undo:\n  " + "\n  ".join(changed))
    for f in selected:
        target = os.path.join(dest, f)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        os.rename(os.path.join(src, f), target)
    print(f"{len(selected)} checked-in generated files moved to {dest}")


main()
