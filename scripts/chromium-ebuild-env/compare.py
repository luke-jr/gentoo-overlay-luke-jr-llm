#!/usr/bin/env python3
"""compare.py BEFORE AFTER: compare two snapshots made by snapshot.sh (see README.md).

For each ebuild in both, prints what differs:
- metadata: the dependency variables, IUSE, SRC_URI, ... compared as multisets of their top-level
  entries (an eclass changes their order), INHERITED as a set, the rest as text;
- functions: by name; a phase that became a wrapper around an eclass's phase function
  (src_prepare() { chromium-llm_src_prepare "$@"; }) is compared with that function;
- variables: by name.
Exits 1 if anything differs. Some differences are expected (a variable the eclass adds, a
function that now reads an array); read each one.
"""
import collections, difflib, os, re, sys

UNORDERED = {"BDEPEND", "DEPEND", "RDEPEND", "PDEPEND", "IDEPEND", "IUSE", "SRC_URI", "RESTRICT",
             "PROPERTIES", "REQUIRED_USE", "LICENSE"}
SETS = {"INHERITED", "DEFINED_PHASES"}
# Set by the eclass mechanism itself, not by the ebuild's code.
IGNORED_VARS = {"ECLASS", "INHERITED", "_CHROMIUM_LLM_ECLASS", "EBUILD", "EBUILD_PHASE_FUNC", "T", "HOME", "TMPDIR",
                "PORTAGE_BUILDDIR", "PORTAGE_LOG_FILE"}


def top_level(s):
    """The top-level entries of a dependency-style string (a group with its condition, a URI with its
    -> name, ...), as a multiset."""
    out, depth, cur = [], 0, []
    for tok in re.sub(r"\s+->\s+", "->", s).split():
        cur.append(tok)
        depth += (tok == "(") - (tok == ")")
        if depth == 0 and not (tok.endswith("?") or tok in ("||", "^^", "??")):
            out.append(" ".join(cur)); cur = []
    if cur:
        out.append(" ".join(cur))
    return collections.Counter(out)


def metadata(path):
    d = {}
    for line in open(path):
        k, _, v = line.rstrip("\n").partition("=")
        d[k] = v
    return d


def functions(path):
    funcs, name, body = {}, None, []
    for line in open(path):
        m = re.match(r"^(\S+) \(\) $", line)
        if m:
            name, body = m.group(1), []
            funcs[name] = body
        elif name:
            body.append(line)
    return {k: "".join(v) for k, v in funcs.items()}


def variables(path):
    v = {}
    for line in open(path):
        m = re.match(r"^declare -\S+ ([A-Za-z_][A-Za-z0-9_]*)(=|$)", line)
        if m:
            v[m.group(1)] = line
        elif v:
            v[list(v)[-1]] += line
    return v


def resolve(funcs):
    """Phase wrappers (EXPORT_FUNCTIONS) replaced by the function they call."""
    out = dict(funcs)
    for k, body in funcs.items():
        m = re.fullmatch(r'\{\s*(\S+_' + re.escape(k) + r') "\$@"\s*\}\s*', body)
        if m and m.group(1) in funcs:
            out[k] = funcs[m.group(1)]
    return out


def main():
    before, after = sys.argv[1:3]
    differ = False
    names = sorted({f[:-9] for f in os.listdir(before) if f.endswith(".metadata")} &
                   {f[:-9] for f in os.listdir(after) if f.endswith(".metadata")})
    for n in names:
        rep = []
        mb, ma = metadata(f"{before}/{n}.metadata"), metadata(f"{after}/{n}.metadata")
        for k in sorted(mb.keys() | ma.keys()):
            a, b = mb.get(k, ""), ma.get(k, "")
            if k in UNORDERED:
                ca, cb = top_level(a), top_level(b)
                if ca != cb:
                    rep.append(f"metadata {k}: only before: {sorted((ca - cb).elements())}; only after: {sorted((cb - ca).elements())}")
            elif k in SETS:
                if set(a.split()) != set(b.split()):
                    rep.append(f"metadata {k}: only before: {sorted(set(a.split()) - set(b.split()))}; only after: {sorted(set(b.split()) - set(a.split()))}")
            elif a != b:
                rep.append(f"metadata {k}: {a!r} -> {b!r}")
        fb, fa = resolve(functions(f"{before}/{n}.functions")), resolve(functions(f"{after}/{n}.functions"))
        for k in sorted(fb.keys() | fa.keys()):
            if k not in fa:
                rep.append(f"function {k}: only before")
            elif k not in fb:
                if not any(fa[k] == fa.get(p) for p in fb):   # a new name for a moved body is fine
                    rep.append(f"function {k}: only after")
            elif fb[k] != fa[k]:
                d = difflib.unified_diff(fb[k].splitlines(), fa[k].splitlines(), lineterm="", n=1)
                rep.append(f"function {k}:\n    " + "\n    ".join(list(d)[2:]))
        vb, va = variables(f"{before}/{n}.variables"), variables(f"{after}/{n}.variables")
        for k in sorted(vb.keys() | va.keys()):
            # The metadata comparison covers the dependency variables (their order may change).
            if k in IGNORED_VARS or k in UNORDERED or vb.get(k) == va.get(k):
                continue
            rep.append(f"variable {k}: {vb.get(k, '(unset)').strip()[:300]} -> {va.get(k, '(unset)').strip()[:300]}")
        print(f"== {n}: {'same' if not rep else str(len(rep)) + ' difference(s)'}")
        for r in rep:
            print("  " + r)
        differ |= bool(rep)
    sys.exit(1 if differ else 0)


main()
