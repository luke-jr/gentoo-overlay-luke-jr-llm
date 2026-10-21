#!/usr/bin/env python3
"""Evaluate Chromium DEPS files as gclient does for a Linux x64 checkout.

Usage:
  deps.py list DEPS                  path, url and revision of every git dependency
  deps.py changed OLD_DEPS NEW_DEPS  the git dependencies whose revision changed
                                     (path url old new; 'new'/'gone' for added/removed),
                                     then the CIPD and GCS dependencies (packages and
                                     objects) that changed, as "nongit path type",
                                     and "gclient_gn_args" if gclient_args.gni changes

Paths are relative to chromium/src (gclient's "src/" prefix removed). Conditions are
evaluated with checkout_linux and checkout_x64 true and the other checkout_* false;
internal (src-internal) and non-git (cipd, gcs) dependencies are left out.
"""
import re
import sys

BUILTINS = {
    "checkout_linux": True, "checkout_x64": True, "host_os": "linux", "host_cpu": "x64",
    "target_os": "linux", "target_cpu": "x64", "checkout_src_internal": False,
    "non_git_source": True, "build_with_chromium": True,
}


class Undefined:
    """Any name the conditions use that isn't defined: false."""
    def __bool__(self):
        return False

    def __eq__(self, other):
        return False

    def __ne__(self, other):
        return True


class Names(dict):
    def __missing__(self, key):
        if key.startswith("checkout_"):
            return False
        return Undefined()


def parse(text):
    """{"deps": {path: (url, rev)}, "recurse": set of paths, "use_relative_paths": bool}"""
    scope = {"Var": lambda n: "{%s}" % n, "Str": lambda s: s}
    exec(text, scope)
    variables = dict(BUILTINS)
    for k, v in scope.get("vars", {}).items():
        variables.setdefault(k, v)

    def fmt(s):
        # Not str.format: variable names may contain dots ('jetstream_2.2_revision').
        for _ in range(5):
            # Names that aren't variables (CIPD's ${{arch}}, ${{platform}}) stay as they are.
            s = re.sub(r"\{([^{}]+)\}", lambda m: str(variables.get(m.group(1), m.group(0))), s)
        return s

    def strip(path):
        return path[4:] if path.startswith("src/") else path

    deps = {}
    nongit = {}
    for path, d in scope.get("deps", {}).items():
        path = fmt(path)  # e.g. 'third_party/golang/linux/{host_cpu}'
        if isinstance(d, str):
            d = {"url": d}
        cond = d.get("condition")
        if cond and not eval(cond, {"__builtins__": {}}, Names(variables)):
            continue
        if d.get("dep_type", "git") in ("cipd", "gcs"):
            # What identifies its content: the packages' versions, the objects' hashes.
            items = [fmt(f"{x['package']}@{x['version']}") for x in d.get("packages", [])]
            items += [f"{x['object_name']}:{x.get('sha256sum')}" for x in d.get("objects", [])]
            nongit[strip(path)] = (d["dep_type"], " ".join(sorted(items)))
            continue
        if d.get("dep_type", "git") != "git" or not d.get("url"):
            continue
        url = fmt(d["url"])
        if "@" not in url:
            continue
        repo, rev = url.rsplit("@", 1)
        if "chrome-internal" in repo:
            continue
        deps[strip(path)] = (repo, rev)
    recurse = set()
    for r in scope.get("recursedeps", []):
        recurse.add(strip(r[0] if isinstance(r, (list, tuple)) else r))
    gn_args = {k: variables.get(k) for k in scope.get("gclient_gn_args", [])}
    return {"deps": deps, "nongit": nongit, "recurse": recurse, "gn_args": gn_args,
            "use_relative_paths": bool(scope.get("use_relative_paths"))}


def load(path):
    return parse(open(path, encoding="utf-8").read())["deps"]


def main():
    if sys.argv[1:2] == ["list"] and len(sys.argv) == 3:
        for p, (u, r) in sorted(load(sys.argv[2]).items()):
            print(p, u, r)
    elif sys.argv[1:2] == ["changed"] and len(sys.argv) == 4:
        texts = [open(f, encoding="utf-8").read() for f in sys.argv[2:4]]
        (old, new) = (parse(t)["deps"] for t in texts)
        for p in sorted(set(old) | set(new)):
            o, n = old.get(p), new.get(p)
            if o == n:
                continue
            print(p, (n or o)[0], o[1] if o else "new", n[1] if n else "gone")
        parsed = [parse(t) for t in texts]
        (old, new) = (p["nongit"] for p in parsed)
        for p in sorted(set(old) | set(new)):
            if old.get(p) != new.get(p):
                print("nongit", p, (new.get(p) or old.get(p))[0])
        if parsed[0]["gn_args"] != parsed[1]["gn_args"]:
            print("gclient_gn_args (build/config/gclient_args.gni changes)")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
