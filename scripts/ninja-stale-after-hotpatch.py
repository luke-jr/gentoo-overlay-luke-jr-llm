#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""List build outputs that may be stale after a patch was applied to the
source tree while ninja was building.

ninja rebuilds an output when an input is newer than the output. A compile
that started before the patch rewrote one of its inputs, but finished after,
read the old contents yet has a newer mtime, so ninja considers it up to
date. This finds outputs whose compile overlapped the time the patched files
were written and whose recorded dependencies include a patched file. Delete
them (--delete) and run ninja again to rebuild just those.

Usage (in the build directory, e.g. out/Release):
  ninja-stale-after-hotpatch.py PATCH [--src ../..] [--ninja ninja] [--delete]
"""

import argparse
import os
import re
import subprocess
import sys


def patched_files(patch, src):
    files = set()
    for line in open(patch, encoding="utf-8", errors="replace"):
        m = re.match(r"^(?:\+\+\+ b/|--- a/)(\S+)", line)
        if m:
            files.add(os.path.normpath(os.path.join(src, m.group(1))))
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("patch")
    ap.add_argument("--src", default="../..", help="source root relative to the build dir")
    ap.add_argument("--ninja", default="ninja")
    ap.add_argument("--slack", type=float, default=5.0,
                    help="seconds added on both sides of the patch window")
    ap.add_argument("--delete", action="store_true")
    args = ap.parse_args()

    patched = patched_files(args.patch, args.src)
    mtimes = [os.stat(f).st_mtime_ns for f in patched if os.path.exists(f)]
    if not mtimes:
        sys.exit("none of the patched files exist (wrong --src?)")
    slack = int(args.slack * 1e9)
    win_start, win_end = min(mtimes) - slack, max(mtimes) + slack
    print(f"patch window: {(win_end - win_start) / 1e9:.1f} s over {len(mtimes)} files",
          file=sys.stderr)

    # Latest log entry per output: start/end are ms since that ninja run began,
    # mtime is the output's mtime (ns) when it finished.
    latest = {}
    with open(".ninja_log") as f:
        header = f.readline()
        if not header.startswith("# ninja log v"):
            sys.exit("unexpected .ninja_log format")
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) >= 4:
                latest[p[3]] = (int(p[0]), int(p[1]), int(p[2]))

    overlapping = []
    for out, (start, end, mtime) in latest.items():
        began = mtime - (end - start) * 1_000_000
        if began <= win_end and mtime >= win_start:
            overlapping.append(out)
    print(f"{len(overlapping)} outputs were being built during the patch window",
          file=sys.stderr)
    if not overlapping:
        return

    # Recorded dependencies (from the deps log) of those outputs.
    deps = subprocess.run([args.ninja, "-t", "deps", *overlapping],
                          capture_output=True, text=True, check=True).stdout
    stale, current = [], None
    for line in deps.splitlines():
        if line and not line.startswith(" "):
            current = line.split(":")[0]
        elif current and os.path.normpath(line.strip()) in patched:
            stale.append(current)
            current = None  # one hit is enough
    gone = 0
    for out in stale:
        if not os.path.exists(out):
            print(f"{out} (already deleted; ninja will rebuild it)")
            gone += 1
            continue
        print(out)
        if args.delete:
            os.remove(out)
            gone += 1
    print(f"{len(stale)} possibly stale, {len(stale) - gone} still present", file=sys.stderr)


if __name__ == "__main__":
    main()
