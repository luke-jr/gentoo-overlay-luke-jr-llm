#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""The kept build tree (CHROMIUM_BUILD_DIR, see the eclass): its owner, and the timestamps of its
sources, so that ninja rebuilds what changed since it last ran and nothing else.

Usage:
  chromium-build-tree.py claim TREE BUILDDIR
    Make the build in Portage's BUILDDIR the tree's user. If another build uses it (its
    Portage build directory is locked), wait until it is done. Run with Portage's Python.
  chromium-build-tree.py settle TREE SRC [--full BUILD_NINJA] [--bootstrap PATH...]
    Before each ninja run: TREE/state has, for every file of SRC (but out/), its contents (a
    hash) and timestamp at the last run, whatever build that was in. A file with the same
    contents gets that timestamp back: what ninja built from it since is newer, so it stays,
    and the rest gets rebuilt. A changed or new file gets the current time. Either way the
    file's contents and timestamp become its record. --full hashes every file (the first run
    of a build); otherwise only files whose timestamp isn't their record's (written since the
    last run) are hashed. With --full, a changed file gets BUILD_NINJA's timestamp minus 1ns
    instead of the current time: gn wrote it after unpacking and before the in-place
    regenerations (whose files are looked at here, after them), so it is newer than every
    output of the earlier builds, and ninja doesn't run gn again for a changed .gn file. But a
    file gn read (BUILD_NINJA.d) that was written after it gets the current time, so that
    ninja runs gn again, as it would without the kept tree. A file that is gone keeps its record: what ninja
    built while it was gone doesn't use it, and if it comes back as it was, what ninja built
    from it before is still right (the build moves checked-in generated files aside, then
    writes them again).
    --bootstrap: files (of SRC) that a tool built from them in this run regenerates in place
    afterwards (protobuf's checked-in protoc output, which protoc is built from). Their record
    is that of the regenerated contents, so here they only get its timestamp back (they aren't
    looked at, and their records stay): the tool built from the regenerated contents stays. One
    without a record gets the current time, and no record yet.
    Whether that was right is up to the caller: after regenerating them, `same` must find
    them unchanged, otherwise the caller has to put the checked-in files back and do it again
    without --bootstrap.
  chromium-build-tree.py same TREE SRC PATH...
    Exit 0 if the contents of these files of SRC are those of their records (or they have
    none), 3 if not.
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


def settle(tree, src, full, build_ninja=None, bootstrap=()):
    path = os.path.join(tree, "state")
    try:
        with open(path) as f:
            records = json.load(f)
    except FileNotFoundError:
        records = {}
    files = walk(src)
    unrecorded = []
    for p in bootstrap:
        if p in files:
            if p not in records:
                unrecorded.append(p)
            elif files[p].st_mtime_ns != records[p][1]:
                os.utime(os.path.join(src, p), ns=(records[p][1], records[p][1]))
            del files[p]
    todo = sorted(p for p, st in files.items() if full or records.get(p, [None, None])[1] != st.st_mtime_ns)
    gn_newer = set()
    if build_ninja:
        # gn wrote both (build.ninja.d lists the inputs of build.ninja.stamp).
        b = min(os.stat(f).st_mtime_ns for f in (build_ninja, build_ninja + ".stamp") if os.path.exists(f))
        with open(build_ninja + ".d") as f:
            for dep in f.read().split(":", 1)[1].split():
                p = os.path.relpath(os.path.normpath(os.path.join(os.path.dirname(build_ninja), dep)), src)
                if p in files and files[p].st_mtime_ns > b:
                    gn_newer.add(p)
    with multiprocessing.Pool() as pool:
        hashes = pool.map(digest, [os.path.join(src, p) for p in todo], chunksize=256)
    now = b - 1 if build_ninja else time.time_ns()
    for p in unrecorded:
        os.utime(os.path.join(src, p), ns=(now, now))
    same = changed = 0
    for p, h in zip(todo, hashes):
        record = records.get(p)
        if p in gn_newer:
            t = time.time_ns()
            os.utime(os.path.join(src, p), ns=(t, t))
            records[p] = [h, t]
            changed += 1
        elif record is not None and record[0] == h:
            if files[p].st_mtime_ns != record[1]:
                os.utime(os.path.join(src, p), ns=(record[1], record[1]))
            same += 1
        else:
            os.utime(os.path.join(src, p), ns=(now, now))
            records[p] = [h, now]
            changed += 1
    with open(path + ".new", "w") as f:
        json.dump(records, f)
    os.replace(path + ".new", path)
    print(f"{len(todo)} of {len(files)} files looked at: {same} unchanged, {changed} changed or new", flush=True)


def same(tree, src, paths):
    with open(os.path.join(tree, "state")) as f:
        records = json.load(f)
    return all(p not in records or (os.path.isfile(os.path.join(src, p))
                                    and digest(os.path.join(src, p)) == records[p][0]) for p in paths)


def main(argv):
    if len(argv) == 4 and argv[1] == "claim":
        claim(argv[2], argv[3])
    elif len(argv) >= 4 and argv[1] == "settle":
        rest = argv[4:]
        build_ninja = None
        if rest[:1] == ["--full"] and len(rest) >= 2:
            build_ninja = rest[1]
            rest = rest[2:]
        if rest and rest[0] != "--bootstrap":
            sys.exit(__doc__)
        settle(argv[2], argv[3], build_ninja is not None, build_ninja, rest[1:])
    elif len(argv) >= 5 and argv[1] == "same":
        sys.exit(0 if same(argv[2], argv[3], argv[4:]) else 3)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
