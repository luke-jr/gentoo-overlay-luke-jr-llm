#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Regenerates chromium-bidi's protocol types (src/protocol/generated/*.ts) and
# Zod schemas (src/protocol-parser/generated/*.ts) with its
# tools/update_bidi_types.py, from CDDL already extracted from the specs.
#
# Usage: chromium-bidi-types.py BIDI_DIR CDDL_DIR [OLD_BIDI_DIR]
#   BIDI_DIR      third_party/chromium-bidi
#   CDDL_DIR      holds NAME/all.cddl for each spec NAME in update_bidi_types.SPECS
#   OLD_BIDI_DIR  where the files being replaced are, if not in BIDI_DIR
#
# Like upstream's full update without its formatting step (prettier and eslint
# --fix, which only change the layout). The copyright year in the header is kept
# from the files being replaced instead of being the current year.

import importlib.util
import re
import sys
from pathlib import Path
from types import SimpleNamespace

bidi, cddl_dir = (Path(a).resolve() for a in sys.argv[1:3])
old_bidi = Path(sys.argv[3]).resolve() if len(sys.argv) > 3 else bidi
spec = importlib.util.spec_from_file_location("update_bidi_types", bidi / "tools" / "update_bidi_types.py")
ubt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ubt)

for s in ubt.SPECS:
    cddl = cddl_dir / s["name"] / "all.cddl"
    if not cddl.is_file():
        sys.exit(f"{cddl} is missing")
    for key, fmt in (("ts_file", "ts"), ("zod_file", "zod")):
        out = bidi / s[key]
        old = (old_bidi / s[key]).read_text(encoding="utf-8")
        year = int(re.search(r"Copyright (\d{4}) Google LLC\.", old)[1])
        # It only uses datetime.datetime.now().year.
        ubt.datetime = SimpleNamespace(datetime=SimpleNamespace(now=lambda y=year: SimpleNamespace(year=y)))
        ubt.run_cddlconv_and_write(cddl, out, fmt)
