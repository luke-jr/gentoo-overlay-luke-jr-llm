#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""List the npm packages a Chromium build uses, for
www-client/chromium/files/chromium-<major>-node-modules.txt.

Run it in a configured and built Chromium build directory (out/Release) whose
source tree still has all of its node_modules (build with the keep list
emptied, or from a tree prepared without pruning). It deletes the outputs of
every build step that can run Node or tsc (the npm packages are only used
there), rebuilds them under strace, and lists the packages whose files were
opened, plus the node_modules files ninja knows as build inputs.

Needs strace. Takes a few minutes.

Usage (in out/Release):
  chromium-node-modules-used.py [-j N] [TARGET...] > chromium-NNN-node-modules.txt
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile

# Build steps that run Node, or tsc (which reads type declarations from
# node_modules): matched against the ninja command.
JS_STEP = re.compile(
    r"node\.py|minify_js\.py|css_to_wrapper\.py|html_to_wrapper\.py|bundle_js\.py"
    r"|minify_lottie\.py|chromium-bidi/tools/build/scripts/rollup\.py|minify_with_terser\.py"
    r"|policy_templates\.py|generate_impl/parse\.py|run_with_stamp\.py|run_with_restat\.py"
    r"|ts_library\.py|protoc-gen-ts|eslint_ts\.py|stylelint\.py")


def ninja_lines(path):
    buf = ""
    for raw in open(path, encoding="utf-8", errors="replace"):
        raw = raw.rstrip("\n")
        if raw.endswith("$") and not raw.endswith("$$"):
            buf += raw[:-1]
            continue
        yield buf + raw
        buf = ""


def ninja_split(s):
    out, cur, i = [], "", 0
    while i < len(s):
        if s[i] == "$" and i + 1 < len(s):
            cur += s[i + 1]
            i += 2
            continue
        if s[i] == " ":
            if cur:
                out.append(cur)
            cur = ""
        else:
            cur += s[i]
        i += 1
    if cur:
        out.append(cur)
    return out


def js_step_outputs(build_dir):
    """Outputs of the build edges whose command matches JS_STEP."""
    outputs = []

    def parse(path, rules):
        rule = None
        for line in ninja_lines(path):
            if line.startswith("rule "):
                rule = line[5:].strip()
                rules[rule] = ""
            elif line.startswith("  command = ") and rule:
                rules[rule] = line[12:]
            elif line.startswith("build "):
                rule = None
                lhs, rhs = re.split(r"(?<!\$):", line[6:], maxsplit=1)
                if JS_STEP.search(rules.get(rhs.split()[0], "")):
                    outputs.extend(ninja_split(lhs.split(" | ")[0]))
            elif line.startswith(("subninja ", "include ")):
                rule = None
                sub = os.path.join(build_dir, line.split(None, 1)[1].strip())
                parse(sub, dict(rules) if line.startswith("subninja ") else rules)
            elif not line.startswith("  "):
                rule = None

    parse(os.path.join(build_dir, "build.ninja"), {})
    return outputs


def package_of(path):
    """The npm package directory a source-relative path is in, or None."""
    if "node_modules/" not in path:
        return None
    pre, rest = path.rsplit("node_modules/", 1)
    parts = rest.split("/")
    n = 2 if parts[0].startswith("@") else 1
    if len(parts) <= n:
        return None
    return pre + "node_modules/" + "/".join(parts[:n])


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("targets", nargs="*", default=["chrome", "chromedriver", "chrome_sandbox"])
    ap.add_argument("-j", default=str(os.cpu_count()))
    ap.add_argument("--ninja", default="ninja")
    args = ap.parse_args()
    build_dir = os.getcwd()
    src = os.path.realpath(os.path.join(build_dir, "../.."))

    closure = subprocess.run([args.ninja, "-t", "inputs", *args.targets], check=True,
                             capture_output=True, text=True).stdout.split("\n")
    in_closure = set(closure)
    outputs = sorted(set(o for o in js_step_outputs(build_dir) if o in in_closure))
    print(f"{len(outputs)} outputs of Node/tsc steps to rebuild", file=sys.stderr)

    packages = {}
    for f in closure:
        if f.startswith("../../"):
            p = package_of(f[6:])
            if p:
                packages.setdefault(p, "build input")

    with tempfile.TemporaryDirectory(dir=build_dir) as tmp:
        phony = os.path.join(tmp, "js.ninja")
        esc = lambda s: s.replace("$", "$$").replace(" ", "$ ").replace(":", "$:")
        with open(phony, "w") as f:
            f.write(f"include {esc(os.path.join(build_dir, 'build.ninja'))}\n")
            f.write("build js_steps: phony " + " ".join(map(esc, outputs)) + "\n")
        for o in outputs:
            path = os.path.join(build_dir, o)
            if os.path.isdir(path) and not os.path.islink(path):
                subprocess.run(["rm", "-r", "--", path], check=True)
            elif os.path.lexists(path):
                os.unlink(path)
        log = os.path.join(tmp, "strace.log")
        # The full log would be several GB; keep only the node_modules lines.
        subprocess.run(["strace", "-f", "-qq", "-e", "trace=%file,execve", "-e", "status=successful",
                        "-o", f"|exec grep -F node_modules > '{log}'",
                        args.ninja, "-f", phony, "-j", args.j, "js_steps"],
                       check=True, stdout=sys.stderr)
        for line in open(log, encoding="utf-8", errors="replace"):
            if "node_modules" not in line:
                continue
            m = re.match(r"\d+\s+(\w+)\((.*)", line)
            if not m or m.group(1) not in ("open", "openat", "execve", "readlink", "readlinkat"):
                continue
            for p in re.findall(r'"([^"]*node_modules[^"]*)"', m.group(2)):
                p = os.path.normpath(os.path.join(build_dir, p))
                if p.startswith(src + "/") and os.path.isfile(p):
                    pkg = package_of(p[len(src) + 1:])
                    if pkg:
                        packages[pkg] = "opened"

    for p in sorted(packages):
        print(p)
    print(f"{len(packages)} packages", file=sys.stderr)


if __name__ == "__main__":
    main()
