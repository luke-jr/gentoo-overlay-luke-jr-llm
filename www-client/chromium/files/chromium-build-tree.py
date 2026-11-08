#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""The kept build tree (CHROMIUM_BUILD_DIR, see the eclass): its owner, and the timestamps of its
sources, so that ninja rebuilds what changed since it last ran and nothing else.

Usage:
  chromium-build-tree.py claim TREE BUILDDIR
    Make the build in Portage's BUILDDIR the tree's user. If another build uses it (its
    Portage build directory is locked), wait until it is done. Run with Portage's Python.
  chromium-build-tree.py settle TREE SRC [--full]
    Before each ninja run: TREE/state has, for every file of SRC (but out/), its contents (a
    hash) and timestamp at the last run, whatever build that was in. A file with the same
    contents gets that timestamp back: what ninja built from it since is newer, so it stays,
    and the rest gets rebuilt. A changed or new file gets the current time. Either way the
    file's contents and timestamp become its record. --full hashes every file (the first run
    of a build, after unpacking); otherwise only files whose timestamp isn't their record's
    (written since the last run) are hashed. A file that is gone loses its record.
"""
import hashlib
import json
import multiprocessing
import os
import sys
import time


def walk(src):
    """The regular files under SRC (relative paths) with their stat results, without out/."""
    files = {}
    stack = [""]
    while stack:
        rel = stack.pop()
        with os.scandir(os.path.join(src, rel)) as it:
            for e in it:
                p = rel + e.name
                if e.is_dir(follow_symlinks=False):
                    if p != "out":
                        stack.append(p + "/")
                elif e.is_file(follow_symlinks=False):
                    files[p] = e.stat(follow_symlinks=False)
    return files


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1 << 20):
            h.update(chunk)
    return h.hexdigest()


def claim(tree, builddir):
    import portage.locks
    from portage.exception import TryAgain

    owner = os.path.join(tree, "owner")
    while True:
        mutex = portage.locks.lockfile(owner, wantnewlockfile=1)
        try:
            try:
                with open(owner) as f:
                    other = f.read().strip()
            except FileNotFoundError:
                other = ""
            busy = False
            if other and other != builddir:
                try:
                    portage.locks.unlockdir(portage.locks.lockdir(other, flags=os.O_NONBLOCK))
                except TryAgain:
                    busy = True
            if not busy:
                with open(owner + ".new", "w") as f:
                    f.write(builddir + "\n")
                os.replace(owner + ".new", owner)
                return
        finally:
            portage.locks.unlockfile(mutex)
        print(f"{tree} is used by the build in {other}: waiting until it is done ...", flush=True)
        portage.locks.unlockdir(portage.locks.lockdir(other))


def settle(tree, src, full):
    path = os.path.join(tree, "state")
    try:
        with open(path) as f:
            records = json.load(f)
    except FileNotFoundError:
        records = {}
    files = walk(src)
    todo = sorted(p for p, st in files.items() if full or records.get(p, [None, None])[1] != st.st_mtime_ns)
    with multiprocessing.Pool() as pool:
        hashes = pool.map(digest, [os.path.join(src, p) for p in todo], chunksize=256)
    now = time.time_ns()
    same = changed = 0
    for p, h in zip(todo, hashes):
        record = records.get(p)
        if record is not None and record[0] == h:
            if files[p].st_mtime_ns != record[1]:
                os.utime(os.path.join(src, p), ns=(record[1], record[1]))
            same += 1
        else:
            os.utime(os.path.join(src, p), ns=(now, now))
            records[p] = [h, now]
            changed += 1
    for p in [p for p in records if p not in files]:
        del records[p]
    with open(path + ".new", "w") as f:
        json.dump(records, f)
    os.replace(path + ".new", path)
    print(f"{len(todo)} of {len(files)} files looked at: {same} unchanged, {changed} changed or new", flush=True)


def main(argv):
    if len(argv) == 4 and argv[1] == "claim":
        claim(argv[2], argv[3])
    elif len(argv) in (4, 5) and argv[1] == "settle" and argv[4:] in ([], ["--full"]):
        settle(argv[2], argv[3], argv[4:] == ["--full"])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
