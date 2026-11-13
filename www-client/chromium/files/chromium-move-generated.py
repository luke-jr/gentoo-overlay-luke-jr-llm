#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Move checked-in generated files out of the source tree, so that the build can only use the
regenerated ones (a regeneration step that doesn't write one makes the build fail).

Usage: chromium-move-generated.py SRC DEST [STAMP [UPSTREAM]] < PATTERNS
       chromium-move-generated.py --record SRC UPSTREAM < PATCHES
  Moves the files of SRC that PATTERNS match to DEST, at the same relative paths. PATTERNS
  has one pattern per line, relative to SRC: '*' and '?' match within a path component,
  '**/' any number of directories, a trailing '/' everything below a directory; '!' before a
  pattern excludes what it matches from the earlier ones. Empty lines and lines starting with
  '#' are ignored. A pattern (or exclusion) that matches nothing is an error, so that a change
  upstream (a renamed or removed file) doesn't go unnoticed. Directories stay.
  With STAMP (a file made when the sources were unpacked), it is an error too if one of the
  files was changed since (by a patch): its regeneration would undo that change.
  With UPSTREAM (written by --record), the changes of upstream's own patches (the upgrade to a
  tag, the branch fixes) are allowed: upstream generated those files from the sources these
  patches change, so the regeneration makes them again. A file changed again after --record
  is still an error.
  --record: writes to UPSTREAM the files that PATCHES (one path per line, git diffs) change,
  each with its modification time, after the patches are applied.
"""
import bisect
import errno
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


def record(src, out):
    paths = set()
    for patch in sys.stdin.read().split("\n"):
        if patch:
            with open(patch, encoding="utf-8", errors="surrogateescape") as f:
                paths |= {m.group(1) for m in re.finditer(r"(?m)^\+\+\+ b/(\S+)$", f.read())}
    with open(out, "w", encoding="utf-8", errors="surrogateescape") as f:
        for p in sorted(paths):
            if os.path.lexists(os.path.join(src, p)):
                f.write(f"{os.lstat(os.path.join(src, p)).st_mtime_ns}\t{p}\n")


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--record":
        return record(*sys.argv[2:])
    if len(sys.argv) not in (3, 4, 5):
        sys.exit(__doc__)
    src, dest = sys.argv[1:3]
    since = os.stat(sys.argv[3]).st_mtime if len(sys.argv) >= 4 else None
    upstream = {}
    if len(sys.argv) == 5:
        with open(sys.argv[4], encoding="utf-8", errors="surrogateescape") as f:
            for line in f:
                ns, _, p = line.rstrip("\n").partition("\t")
                upstream[p] = int(ns)
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
        changed = [f for f in selected if os.lstat(os.path.join(src, f)).st_mtime > since and
                   upstream.get(f) != os.lstat(os.path.join(src, f)).st_mtime_ns]
        if changed:
            sys.exit("These checked-in generated files were changed after unpacking (by a patch?), which "
                     "their regeneration would undo:\n  " + "\n  ".join(changed))
    for f in selected:
        target = os.path.join(dest, f)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        try:
            os.rename(os.path.join(src, f), target)
        except OSError as e:
            if e.errno == errno.EXDEV:
                sys.exit(f"{dest} is on another filesystem than {src}: it must be on the same one")
            raise
    print(f"{len(selected)} checked-in generated files moved to {dest}")


main()
