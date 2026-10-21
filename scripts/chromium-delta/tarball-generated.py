#!/usr/bin/env python3
"""List the files of a Chromium source tarball that are in none of the git repositories it was
checked out from: what the tarball process generated or downloaded (lastchange.py's stamps,
PGO profiles, hook downloads, ...). Each of them must be classified in generated.conf.

Usage: tarball-generated.py TARBALL TAG CACHE_DIR [CONF]
  TARBALL    chromium-<version>(-lite|-linux).tar.xz
  TAG        the chromium/src tag it was made from (e.g. 156.0.8078.12)
  CACHE_DIR  where the (blobless, depth-1) clones go
  CONF       generated.conf: classify the files with it, and fail if any isn't

Writes "path<TAB>source" lines to stdout. source is "nongit <dep>" for the files of a CIPD
or GCS dependency (their changes show in `deps.py changed`), else the generated.conf line
that covers the path ("UNCLASSIFIED" if none does). Follows DEPS and recursedeps like
gclient, for a Linux x64 checkout (see deps.py).
"""
import fnmatch
import base64
import concurrent.futures
import os
import subprocess
import sys
import tarfile
import threading
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import deps  # noqa: E402

CHROMIUM = "https://chromium.googlesource.com/chromium/src.git"


def git(repo, *args, **kw):
    return subprocess.run(["git", "-C", repo, *args], check=True, capture_output=True, **kw).stdout


LOCKS = {}
LOCKS_LOCK = threading.Lock()


def fetch(cache, url, rev):
    """A blobless depth-1 clone of url at rev; returns the repository path."""
    name = url.split("://", 1)[1].replace("/", "_")
    with LOCKS_LOCK:
        lock = LOCKS.setdefault(name, threading.Lock())
    with lock:  # several dependencies may come from one repository
        return fetch_locked(cache, url, rev, name)


def fetch_locked(cache, url, rev, name):
    repo = os.path.join(cache, name)
    if not os.path.isdir(repo):
        subprocess.run(["git", "init", "-q", "--bare", repo], check=True)
        # A partial clone's remote, so that blobs (DEPS) can be fetched when read.
        git(repo, "remote", "add", "origin", url)
        git(repo, "config", "remote.origin.promisor", "true")
        git(repo, "config", "remote.origin.partialclonefilter", "blob:none")
    ref = f"refs/x/{rev.rsplit('/', 1)[-1]}"
    try:
        git(repo, "rev-parse", "--verify", "-q", ref)
    except subprocess.CalledProcessError:
        for i in range(4):
            try:
                git(repo, "fetch", "-q", "--filter=blob:none", "--depth=1", "origin", f"+{rev}:{ref}")
                break
            except subprocess.CalledProcessError as e:
                if i == 3:
                    sys.exit(f"Failed to fetch {url} {rev}: {e.stderr.decode(errors='replace')}")
                time.sleep(10 * (i + 1))
    return repo, ref


def read_deps(repo, ref, url, rev):
    """The DEPS file at rev: from Gitiles (googlesource.com), else through git (slow: a
    partial clone fetches the blob on demand)."""
    if ".googlesource.com/" in url:
        for i in range(6):
            try:
                data = urllib.request.urlopen(
                    f"{url.removesuffix('.git')}/+/{rev}/DEPS?format=TEXT", timeout=60).read()
                return base64.b64decode(data).decode("utf-8")
            except OSError:
                time.sleep(5 * (i + 1))
    return git(repo, "show", f"{ref}:DEPS", text=True)


def tree(repo, ref):
    return git(repo, "ls-tree", "-r", "-z", "--full-tree", ref).split(b"\0")


def main():
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)
    tarball, tag, cache = sys.argv[1:4]
    conf = []
    if len(sys.argv) == 5:
        for line in open(sys.argv[4]):
            if line.strip() and not line.startswith("#"):
                pattern, decision, reason = line.rstrip("\n").split("\t", 2)
                conf.append((pattern, f"{decision}: {reason}"))
    nongit = {}
    os.makedirs(cache, exist_ok=True)
    tracked = set()
    todo = [("", CHROMIUM, f"refs/tags/{tag}", True)]  # (path prefix, url, rev, recurse)
    seen = set()
    with concurrent.futures.ThreadPoolExecutor(8) as ex:
        while todo:
            batch, todo = todo, []
            for (prefix, url, rev, recurse), (repo, ref) in zip(
                    batch, ex.map(lambda t: fetch(cache, t[1], t[2]), batch)):
                for entry in tree(repo, ref):
                    if not entry:
                        continue
                    meta, path = entry.split(b"\t", 1)
                    if meta.split()[1] == b"commit":  # gitlinks are the deps themselves
                        continue
                    tracked.add(prefix + path.decode("utf-8", "surrogateescape"))
                if not recurse:
                    continue
                depsfile = read_deps(repo, ref, url, rev)
                d = deps.parse(depsfile)
                rel = d["use_relative_paths"]
                for p in d["nongit"]:
                    nongit[((prefix + p) if rel else p).rstrip("/") + "/"] = p
                for p, (u, r) in d["deps"].items():
                    full = (prefix + p) if rel else p
                    key = (full, u, r)
                    if key in seen:
                        continue
                    seen.add(key)
                    todo.append((full.rstrip("/") + "/", u, r, p in d["recurse"]))
    unclassified = 0
    with tarfile.open(tarball, "r|xz") as t:
        for m in t:
            if not (m.isfile() or m.issym()):
                continue
            name = m.name.split("/", 1)[1] if "/" in m.name else m.name
            if name in tracked:
                continue
            dep = next((d for d in nongit if name.startswith(d)), None)
            if dep:
                source = f"nongit {dep.rstrip('/')}"
            else:
                source = next((c for pat, c in conf if fnmatch.fnmatchcase(name, pat)), "UNCLASSIFIED")
                unclassified += source == "UNCLASSIFIED"
            print(f"{name}\t{source}")
    if conf and unclassified:
        sys.exit(f"{unclassified} generated files are in no CIPD/GCS dependency and not in {sys.argv[4]}")


main()
