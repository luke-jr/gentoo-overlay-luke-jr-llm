#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Build chromedriver's Selenium atoms (third_party/selenium-atoms/atoms.{h,cc})
from Selenium's JavaScript sources without Closure Compiler.

Selenium's Bazel build compiles each atom (closure_fragment) with Closure
Compiler: it resolves Closure's goog.provide/goog.require module system,
applies Chrome's --define flags, optimizes (ADVANCED) and wraps the result in a
function. This does the same without the optimization: the files each atom
needs are concatenated in dependency order (uncompiled Closure, with the
defines given through CLOSURE_UNCOMPILED_DEFINES), wrapped like Selenium's
fragment.bzl does, and minified with esbuild. The atoms are larger, but
behave the same.

Closure's uncompiled namespaces live on goog.global, which is `this` in the
wrapper: an object of its own for each call (reading through to the page's
window), which the code runs `with`, so nothing is added to the page's globals.

Usage: chromium-selenium-atoms.py SELENIUM_SRC ESBUILD OUT_DIR
  writes OUT_DIR/atoms.h and OUT_DIR/atoms.cc with Selenium's gen_file.py.
"""
import os
import re
import subprocess
import sys
import tempfile

src, esbuild, out_dir = sys.argv[1:4]

SOURCE_ROOTS = ["javascript/atoms", "javascript/webdriver", "javascript/chrome-driver",
                "third_party/closure/goog"]

# fragment.bzl's defines for Chrome; closure_js_binary's debug=False sets goog.DEBUG.
DEFINES = {
    "goog.DEBUG": False,
    "goog.userAgent.ASSUME_WEBKIT": True,
    "goog.userAgent.product.ASSUME_CHROME": True,
    "goog.NATIVE_ARRAY_PROTOTYPES": False,
}
EXPORT = "se_exportedFunctionSymbol"

PROVIDE = re.compile(r"""^\s*goog\.(provide|module)\(\s*['"]([\w.$]+)['"]\s*\)""", re.M)
REQUIRE = re.compile(r"""goog\.require\(\s*['"]([\w.$]+)['"]\s*\)""")
COMMENTS = re.compile(r"/\*.*?\*/|//[^\n]*", re.S)


def atoms():
    """name -> (module, function) for the atoms in chrome-driver's ATOMS list."""
    labels = re.search(r"^ATOMS = \[(.*?)^\]", open(os.path.join(src, "javascript/chrome-driver/BUILD.bazel")).read(),
                       re.S | re.M).group(1)
    rule = re.compile(r"closure_fragment\((.*?)\n\)", re.S)
    found = {}
    for label in re.findall(r'"([^"]+)"', labels):
        pkg, _, target = label.rpartition(":")
        pkg = pkg[2:] if pkg.startswith("//") else "javascript/chrome-driver"
        if not target.endswith("-chrome"):
            sys.exit(f"unexpected atom {label}")
        target = target[:-len("-chrome")]
        for body in rule.findall(open(os.path.join(src, pkg, "BUILD.bazel")).read()):
            attr = dict(re.findall(r'^\s*(\w+)\s*=\s*"([^"]*)"', body, re.M))
            if attr.get("name") == target:
                found[target.replace("-", "_")] = (attr["module"], attr["function"])
                break
        else:
            sys.exit(f"no closure_fragment {target} in {pkg}")
    return found


def index():
    """namespace -> (file, is_goog_module, requires)."""
    provides = {}
    for root in SOURCE_ROOTS:
        for dirpath, dirnames, files in os.walk(os.path.join(src, root)):
            dirnames[:] = [d for d in dirnames if d not in ("testing", "test", "demos")]
            for f in files:
                if not f.endswith(".js") or f.endswith("_test.js"):
                    continue
                path = os.path.join(dirpath, f)
                text = open(path, encoding="utf-8").read()
                code = COMMENTS.sub("", text)
                decls = PROVIDE.findall(code)
                if not decls:
                    continue
                requires = REQUIRE.findall(code)
                for kind, ns in decls:
                    if ns in provides and provides[ns][0] != path:
                        sys.exit(f"{ns} is provided by {provides[ns][0]} and {path}")
                    provides[ns] = (path, kind == "module", requires)
    return provides


def ordered_files(entry_requires, provides):
    order, seen = [], set()

    def visit(ns, chain):
        if ns not in provides:
            sys.exit(f"nothing provides {ns} (required by {' <- '.join(chain)})")
        path, _, requires = provides[ns]
        if path in seen:
            return
        seen.add(path)
        for r in requires:
            visit(r, chain + [ns])
        order.append(path)

    for ns in entry_requires:
        visit(ns, ["<atom>"])
    return order


def build(module, function, provides):
    path_is_module = {p: m for p, m, _ in provides.values()}
    parts = [
        "var CLOSURE_NO_DEPS = true;",
        "var CLOSURE_UNCOMPILED_DEFINES = %s;" % (
            "{" + ", ".join("'%s': %s" % (k, str(v).lower()) for k, v in DEFINES.items()) + "}"),
        "this.CLOSURE_NO_DEPS = CLOSURE_NO_DEPS;",
        "this.CLOSURE_UNCOMPILED_DEFINES = CLOSURE_UNCOMPILED_DEFINES;",
        open(os.path.join(src, "third_party/closure/goog/base.js"), encoding="utf-8").read(),
        # Uncompiled, the namespaces goog.provide() creates hang off goog.global, and code
        # names them as globals: `goog` there must be base.js' goog.
        "goog.global.goog = goog;",
    ]
    for path in ordered_files([module], provides):
        text = open(path, encoding="utf-8").read()
        if path_is_module[path]:
            text = "goog.loadModule(function(exports) {'use strict';\n%s\n;return exports;});" % text
        parts.append(text)
    parts.append("goog.require('%s');\ngoog.exportSymbol('%s', %s);" % (module, EXPORT, function))
    # The code runs `with` goog.global, so that the namespaces it names as globals resolve to
    # it (and everything else to the page's globals).
    body = "with (this) {\n%s\n}" % "\n".join(parts)
    # fragment.bzl's output_wrapper, with goog.global an object of its own for each call: a
    # proxy that keeps Closure's namespaces and reads everything else from the page's window
    # (window's own methods bound to it).
    scope = ("new Proxy({}, {get: function(t, k) { if (k in t) return t[k]; var v = window[k];"
             " return typeof v == 'function' && !/^[A-Z]/.test(String(k)) ? v.bind(window) : v; },"
             " has: function(t, k) { return k in t; }})")
    return ("function(){return (function(){%s;\nreturn this.%s.apply(null,arguments);})"
            ".apply(%s, arguments);}" % (body, EXPORT, scope))


def minify(code):
    # esbuild wants a statement: minify `x=<function>`, then take the function back out.
    res = subprocess.run([esbuild, "--minify", "--target=chrome120", "--log-level=warning",
                          "--legal-comments=none", "--charset=utf8"],
                         input=("x=" + code).encode(), capture_output=True, check=True)
    out = res.stdout.decode().strip()
    if not out.startswith("x=") or not out.endswith(";"):
        sys.exit("unexpected esbuild output: " + out[:80])
    return out[2:-1]


provides = index()
with tempfile.TemporaryDirectory() as tmp:
    args = []
    for name, (module, function) in sorted(atoms().items()):
        path = os.path.join(tmp, name + ".js")
        with open(path, "w", encoding="utf-8") as f:
            f.write(minify(build(module, function, provides)))
        args += [name, path]
    gen = os.path.join(src, "javascript/private/gen_file.py")
    for lang, out in (("hdecl", "atoms.h"), ("cc", "atoms.cc")):
        subprocess.run([sys.executable, "-B", "-W", "ignore::SyntaxWarning", gen, lang, os.path.join(out_dir, out), "", "true"] + args,
                       check=True)
