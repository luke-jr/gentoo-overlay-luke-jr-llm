#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Regenerates Chromium's SQLite amalgamation (third_party/sqlite/src/amalgamation:
# sqlite3.c, sqlite3.h, shell/shell.c, rename_exports.h) with its
# scripts/generate_amalgamation.py, for the "chromium" configuration the build uses.
#
# Usage: chromium-sqlite-amalgamation.py SQLITE_DIR [OLD_AMALGAMATION_DIR]
#   SQLITE_DIR  third_party/sqlite
#   OLD_AMALGAMATION_DIR  where the checked-in amalgamation is, if not in place
#
# Differences from running the script as upstream does:
# - ICU's compiler and linker flags are left out: the script would pass icu-config's
#   output as Python bytes literals, which breaks configure; they only affect how
#   SQLite's own tools would be built, not the amalgamation.
# - The tarball lacks SQLite's test/ directory (and the ebuild deletes its prebuilt
#   tool/win/sqlite.vsix), so its manifest check lists those files as changed in
#   sqlite3.c's header comment and marks the source ID as modified ("alt1"). The lines
#   for files that don't exist are dropped and SQLITE_SOURCE_ID (a version stamp) is
#   kept from the files being replaced.

import importlib.util
import os
import re
import sys

root = os.path.abspath(sys.argv[1])
amalgamation = os.path.join(root, "src", "amalgamation")
# Where the checked-in amalgamation is, for its SQLITE_SOURCE_ID (if not in place).
old_amalgamation = sys.argv[2] if len(sys.argv) > 2 else amalgamation
source_id = re.compile(r'^#define SQLITE_SOURCE_ID .*$', re.M)


def read(name, directory=amalgamation):
    with open(os.path.join(directory, name), encoding="utf-8", errors="surrogateescape") as f:
        return f.read()


old_id = source_id.search(read("sqlite3.h", old_amalgamation))[0]

spec = importlib.util.spec_from_file_location(
    "generate_amalgamation", os.path.join(root, "scripts", "generate_amalgamation.py"))
gen = importlib.util.module_from_spec(spec)
sys.path.insert(0, os.path.join(root, "scripts"))
spec.loader.exec_module(gen)
gen._icu_cpp_flags = gen._icu_ld_flags = lambda: ""
gen.make_aggregate("chromium")

for name in ("sqlite3.c", "sqlite3.h"):
    text = read(name)
    text, n = source_id.subn(old_id, text)
    if n != 1:
        sys.exit(f"{name}: expected one SQLITE_SOURCE_ID, found {n}")
    if name == "sqlite3.c":
        start = text.index(" with changes in files:\n")
        end = text.index("\n*/", start)
        changes = re.sub(r'^\*\*    (\S[^\n]*)\n',
                         lambda m: m[0] if os.path.exists(os.path.join(root, "src", m[1])) else "",
                         text[start:end + 1], flags=re.M)
        text = text[:start] + changes + text[end + 1:]
    with open(os.path.join(amalgamation, name), "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write(text)

gen.extract_sqlite_api("chromium")
