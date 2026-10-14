#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Find (and optionally delete) compiled code and opaque archives in a
Chromium source tree.

Detects files by content, not by name:
- compiled code: ELF, PE, COFF objects, Mach-O, WebAssembly, LLVM bitcode,
  SPIR-V, Java class files, DEX, ar archives (static libraries / object
  bundles), Python bytecode;
- archives, whose contents could hide any of the above: zip (incl. .jar,
  .apk, .whl, .crx), 7z, gzip, xz, bzip2 and zstd streams. None of these are
  inputs of the Linux build (the tree ships unpacked copies where needed);
- WebAssembly embedded as base64 in JavaScript/TypeScript/JSON/HTML.

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
    (b"BC\xc0\xde", "LLVM bitcode"),
    (b"\xde\xc0\x17\x0b", "LLVM bitcode"),  # wrapper header
    (b"\x03\x02\x23\x07", "SPIR-V"),
    (b"\x07\x23\x02\x03", "SPIR-V"),
    (b"PK\x03\x04", "zip archive"),
    (b"PK\x05\x06", "zip archive"),  # empty zip
    (b"Cr24", "CRX archive"),
    (b"7z\xbc\xaf\x27\x1c", "7z archive"),
    (b"\x1f\x8b", "gzip archive"),
    (b"\xfd7zXZ\x00", "xz archive"),
    (b"BZh", "bzip2 archive"),
    (b"\x28\xb5\x2f\xfd", "zstd archive"),
)

# COFF object files have only a 2-byte machine type as magic, far too weak on
# its own; only consider files named like objects/import libraries.
COFF_MACHINES = (b"\x4c\x01", b"\x64\x86", b"\x64\xaa", b"\xc4\x01")
COFF_EXTENSIONS = (".obj", ".o", ".lib")

# The WebAssembly header ("\0asm", version 1) in base64, at each of the three
# possible byte alignments (only the characters it fully determines).
BASE64_WASM = (b"AGFzbQEAAA", b"Bhc20BAAAA", b"AYXNtAQAAA")
TEXT_EXTENSIONS = (".js", ".mjs", ".cjs", ".ts", ".mts", ".cts", ".json", ".html", ".htm")


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


def has_base64_wasm(path):
    with open(path, "rb") as f:
        data = f.read()
    return any(m in data for m in BASE64_WASM)


def classify(path):
    try:
        with open(path, "rb") as f:
            head = f.read(8)
        for magic, kind in MAGIC:
            if head.startswith(magic):
                return kind
        if is_pe(path, head):
            return "PE"
        if is_pyc(path, head):
            return "Python bytecode"
        if path.endswith(COFF_EXTENSIONS) and head[:2] in COFF_MACHINES:
            return "COFF object"
        if path.endswith(TEXT_EXTENSIONS) and has_base64_wasm(path):
            return "base64 WebAssembly"
    except OSError:
        return None
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
