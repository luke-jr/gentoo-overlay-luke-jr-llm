#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Find (and optionally delete) compiled code in a Chromium source tree.

Detects files by content, not by name: ELF, PE, Mach-O, WebAssembly, Java
class files, DEX, ar archives (static libraries / object bundles), Python
bytecode, plus zip-based Java/Android archives (.jar/.aar/.apk) and Node.js
native addons (.node, when they are binaries).

Paths given with --allow (relative to the tree) are reported but never
deleted and do not count as failures.  Symlinks are skipped (the ebuild links
system tools into the tree).

Exit status: 0 if nothing (besides allowed files) remains, 1 otherwise.
"""

import argparse
import os
import sys

MAGIC = (
    (b"\x7fELF", "ELF"),
    (b"\x00asm", "WebAssembly"),
    (b"\xfe\xed\xfa\xce", "Mach-O"),
    (b"\xfe\xed\xfa\xcf", "Mach-O"),
    (b"\xce\xfa\xed\xfe", "Mach-O"),
    (b"\xcf\xfa\xed\xfe", "Mach-O"),
    # Mach-O universal binary or Java class file; both are compiled code.
    (b"\xca\xfe\xba\xbe", "Mach-O universal / Java class"),
    (b"dex\n", "DEX"),
    (b"!<arch>\n", "ar archive"),
)

ZIP_CODE_EXTENSIONS = (".jar", ".aar", ".apk")


def is_pe(path, head):
    if not head.startswith(b"MZ"):
        return False
    with open(path, "rb") as f:
        data = f.read(4096)
    if len(data) < 0x40:
        return False
    offset = int.from_bytes(data[0x3C:0x40], "little")
    return 0 < offset <= len(data) - 4 and data[offset:offset + 4] == b"PE\0\0"


def is_pyc(path, head):
    # Python bytecode: 2-byte magic number followed by b"\r\n".
    return path.endswith(".pyc") and head[2:4] == b"\r\n"


def classify(path):
    try:
        with open(path, "rb") as f:
            head = f.read(8)
    except OSError:
        return None
    for magic, kind in MAGIC:
        if head.startswith(magic):
            return kind
    if is_pe(path, head):
        return "PE"
    if is_pyc(path, head):
        return "Python bytecode"
    if path.endswith(ZIP_CODE_EXTENSIONS) and head.startswith(b"PK\x03\x04"):
        return "Java/Android archive"
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", help="source tree to scan")
    parser.add_argument("--allow", action="append", default=[],
                        help="tree-relative path that may stay (repeatable)")
    parser.add_argument("--delete", action="store_true",
                        help="delete everything found that is not allowed")
    parser.add_argument("--exclude-dir", action="append", default=[],
                        help="tree-relative directory to skip, e.g. the build output (repeatable)")
    args = parser.parse_args()

    root = os.path.abspath(args.root)
    allowed = {os.path.normpath(p) for p in args.allow}
    excluded = {os.path.normpath(p) for p in args.exclude_dir}
    remaining = []

    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root)
        dirnames[:] = [d for d in dirnames
                       if os.path.normpath(os.path.join(rel_dir, d)) not in excluded]
        for name in filenames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path) or not os.path.isfile(path):
                continue
            kind = classify(path)
            if kind is None:
                continue
            rel = os.path.normpath(os.path.relpath(path, root))
            if rel in allowed:
                print(f"allowed  {kind:30} {rel}")
            elif args.delete:
                os.remove(path)
                print(f"deleted  {kind:30} {rel}")
            else:
                print(f"FOUND    {kind:30} {rel}")
                remaining.append(rel)

    if remaining:
        print(f"{len(remaining)} file(s) with compiled code remain", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
