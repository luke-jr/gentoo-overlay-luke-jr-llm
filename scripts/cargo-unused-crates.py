#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""List the crates in a Cargo.lock that are never built for the given targets,
in CRATES syntax (name@version), for CARGO_STUB_CRATES (cargo-stubs.eclass).

cargo needs every locked crate to resolve, so run this where they are
available: with network access, or in an unpacked ebuild with
CARGO_HOME=${WORKDIR}/cargo_home and --offline.

Usage:
  cargo-unused-crates.py [--target TRIPLE]... [--cargo cargo] [--offline] DIR
"""

import argparse
import json
import os
import subprocess
import sys
import tomllib


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dir", help="directory with Cargo.toml and Cargo.lock")
    ap.add_argument("--target", action="append",
                    help="target triple (repeatable; default: the Linux "
                         "targets for the ebuilds' KEYWORDS, amd64 and arm64)")
    ap.add_argument("--cargo", default=os.environ.get("CARGO", "cargo"))
    ap.add_argument("--offline", action="store_true")
    args = ap.parse_args()
    targets = args.target or ["x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu"]

    cmd = [args.cargo, "metadata", "--format-version", "1", "--locked"]
    if args.offline:
        cmd.append("--offline")
    for t in targets:
        cmd += ["--filter-platform", t]
    meta = json.loads(subprocess.run(cmd, cwd=args.dir, stdout=subprocess.PIPE,
                                     check=True).stdout)
    built = {(p["name"], p["version"]) for p in meta["packages"]}

    lock = tomllib.load(open(os.path.join(args.dir, "Cargo.lock"), "rb"))
    unused = sorted((p["name"], p["version"]) for p in lock["package"]
                    if p.get("source", "").startswith("registry+")
                    and (p["name"], p["version"]) not in built)
    for name, version in unused:
        print(f"{name}@{version}")
    print(f"{len(unused)} of {len(lock['package'])} locked packages are not built for "
          + ", ".join(targets), file=sys.stderr)


if __name__ == "__main__":
    main()
