#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Generate www-client/chromium-build-deps-<PV>.ebuild from the build
dependencies (DEPEND + BDEPEND) of www-client/chromium-<PV> in this repository.

The dependency strings are taken from Portage's metadata for the Chromium
ebuild (so eclass-generated parts are included) and copied with their USE
conditionals intact; Portage evaluates them against the meta-package's own USE
flags, which should be set like Chromium's. Slot operators are dropped (they
only mean something for packages that link against the dependency), blockers
are dropped, and duplicate top-level items are merged.

USE flags the profile masks for Chromium (e.g. ::gentoo masks system-icu) are
masked for the meta-package as well, in this repository's
profiles/package.use.mask (a generated block).

Run inside the build environment; writes the ebuild and the mask block:
  scripts/gen-chromium-build-deps.py 156.0.8078.12
"""

import os
import re
import sys

import portage

REPO = "luke-jr-llm"
# Flags provided by inherited eclasses or the profile (arch, USE_EXPAND).
IMPLICIT = re.compile(r"^(llvm_slot_\d+|python_targets_\w+|python_single_target_\w+|"
                      r"alpha|amd64|arm|arm64|hppa|loong|m68k|mips|ppc|ppc64|riscv|s390|sparc|x86)$")


def tokens(depstr):
    return depstr.split()


def top_level_items(toks):
    """Split a token list into top-level items: an atom, or a conditional /
    any-of / all-of group including its parenthesized block."""
    items, i = [], 0
    while i < len(toks):
        start = i
        if toks[i].endswith("?") or toks[i] == "||":
            i += 1  # the group follows
        if toks[i] == "(":
            depth = 0
            while True:
                depth += {"(": 1, ")": -1}.get(toks[i], 0)
                i += 1
                if depth == 0:
                    break
        else:
            i += 1
        items.append(toks[start:i])
    return items


def clean(tok):
    if tok in ("(", ")", "||") or tok.endswith("?"):
        return tok
    if tok.startswith("!"):
        return None  # blocker
    tok = re.sub(r":([^\[:/=]*)(/[^\[:=]*)?=?(?=\[|$)", r":\1", tok).replace(":[", "[")
    return tok[:-1] if tok.endswith(":") else tok


def fmt(toks, indent=1):
    out, depth = [], indent
    line = []
    for t in toks:
        if t == ")":
            depth -= 1
            out.append("\t" * depth + ")")
            continue
        line.append(t)
        if t == "(":
            out.append("\t" * depth + " ".join(line))
            line = []
            depth += 1
        elif not (t.endswith("?") or t == "||"):
            out.append("\t" * depth + " ".join(line))
            line = []
    return "\n".join(out)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    pv = sys.argv[1]
    cpv = f"www-client/chromium-{pv}"
    portdb = portage.db[portage.root]["porttree"].dbapi
    path = portdb.findname(cpv, myrepo=REPO)
    if not path:
        sys.exit(f"{cpv} not found in ::{REPO}")
    iuse, depend, bdepend = portdb.aux_get(cpv, ["IUSE", "DEPEND", "BDEPEND"], myrepo=REPO)
    llvm_compat = re.search(r"^LLVM_COMPAT=\(([^)]*)\)", open(path).read(), re.M)
    if not llvm_compat:
        sys.exit("LLVM_COMPAT not found in the Chromium ebuild")

    items, seen = [], set()
    for depstr in (depend, bdepend):
        for item in top_level_items(tokens(depstr)):
            item = [c for c in map(clean, item) if c is not None]
            key = " ".join(item)
            if item and key not in seen:
                seen.add(key)
                items.append(item)
    flat = [t for item in items for t in item]

    # USE flags the dependencies refer to, with Chromium's defaults.
    used = set()
    for t in flat:
        if t.endswith("?"):
            used.add(t.lstrip("!").rstrip("?"))
        for m in re.finditer(r"\[([^\]]*)\]", t):
            for u in m.group(1).split(","):
                if u.endswith(("?", "=")):
                    used.add(u.lstrip("!-").rstrip("?=").split("(")[0])
    defaults = {f.lstrip("+-"): f.startswith("+") for f in iuse.split()}
    # Flags the profile masks for Chromium get the same mask (written below).
    settings = portage.config(clone=portage.settings)
    settings.setcpv(cpv, mydb=portdb)
    flags = sorted(u for u in used if not IMPLICIT.match(u))
    missing = [u for u in flags if u not in defaults]
    if missing:
        sys.exit(f"flags not in Chromium's IUSE: {missing}")
    iuse_out = " ".join(("+" if defaults[u] else "") + u for u in flags)
    masked = sorted(u for u in flags if u in settings.usemask)

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    write_mask(os.path.join(root, "profiles", "package.use.mask"), cpv, masked)
    out = os.path.join(root, "www-client", "chromium-build-deps", f"chromium-build-deps-{pv}.ebuild")
    with open(out, "w") as f:
        f.write(f"""# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# GENERATED by scripts/gen-chromium-build-deps.py from {cpv}::{REPO}
# (its DEPEND and BDEPEND). Do not edit; regenerate for every Chromium version.
#
# Meta-package: everything needed to build Chromium, but not Chromium itself,
# e.g. to keep a build machine's toolchain in @world. Give it the same USE flags
# as www-client/chromium.

LLVM_COMPAT=({llvm_compat.group(1)})

inherit llvm-r1

DESCRIPTION="Build dependencies of www-client/chromium (meta-package)"
HOMEPAGE="https://www.chromium.org/"
S="${{WORKDIR}}"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="{iuse_out}"

RDEPEND="
{fmt(flat)}
"
""")
    print(f"wrote {out}; masked: {', '.join(masked) or 'none'}")


BEGIN = "# BEGIN generated by scripts/gen-chromium-build-deps.py"
END = "# END generated by scripts/gen-chromium-build-deps.py"


def write_mask(path, cpv, masked):
    """Replace the generated block in profiles/package.use.mask."""
    try:
        text = open(path).read()
    except FileNotFoundError:
        text = ""
    if BEGIN in text:
        text = text[:text.index(BEGIN)] + text[text.index(END) + len(END) + 1:]
    block = [BEGIN,
             f"# The profile masks these for {cpv}; mask them for the build",
             "# dependencies the same way."]
    block += [f"www-client/chromium-build-deps {u}" for u in masked]
    block.append(END)
    text = text.rstrip("\n") + ("\n\n" if text.strip() else "") + "\n".join(block) + "\n"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


if __name__ == "__main__":
    main()
