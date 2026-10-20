#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Regenerates V8's static roots for Chromium's configuration (intl, WebAssembly) the way
# its tools/dev/gen-static-roots.py does, with a mksnapshot already built with
# v8_enable_static_roots_generation=true: writes src/roots/static-roots-intl-wasm.h, then
# updates the values include/v8-internal.h takes from the static roots files
# (update_v8_internal_h(), which checks them against the other configurations' files).
#
# Usage: chromium-v8-static-roots.py V8_DIR MKSNAPSHOT

import contextlib
import io
import subprocess
import sys
from pathlib import Path

v8, mksnapshot = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()

subprocess.run([mksnapshot, "--static-roots-src", v8 / "src" / "roots" / "static-roots-intl-wasm.h"],
               check=True)

# The script's definitions, without its main part (which builds every configuration).
script = v8 / "tools" / "dev" / "gen-static-roots.py"
source = script.read_text()
source = source[:source.index("\nall_configs = (")]
sys.argv = [str(script)]
defs = {"__file__": str(script), "__name__": "gen_static_roots"}
exec(compile(source, str(script), "exec"), defs)
if defs["V8_PATH"] != v8:
    sys.exit(f"gen-static-roots.py's V8_PATH is {defs['V8_PATH']}, expected {v8}")
# It returns False both when nothing changed and after printing an error or warning.
out = io.StringIO()
with contextlib.redirect_stdout(out):
    defs["update_v8_internal_h"]()
print(out.getvalue(), end="")
if "Error:" in out.getvalue() or "Warning:" in out.getvalue():
    sys.exit("Failed to update v8-internal.h")
