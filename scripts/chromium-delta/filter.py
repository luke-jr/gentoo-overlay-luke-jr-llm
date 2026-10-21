#!/usr/bin/env python3
"""Filter upstream diffs down to what can affect this overlay's Linux build.

Usage: filter.py [--branch-fixes] OUT_DIR TREE_FILES BUILD_INPUTS DIFF:PREFIX...
  --branch-fixes  for changes after a release (up to a branch head): chrome/VERSION stays at
                  the release's version (without it, a version-to-version patch, it's kept)
  OUT_DIR       gets kept/<diff> (the kept file diffs, paths relative to the diff's repo) and
                report.tsv (path, decision, reason: one line per file of every diff)
  TREE_FILES    the files of the tree the result applies to (one path per line)
  BUILD_INPUTS  files a build reads (ninja -t inputs, and GN's build.ninja.d; several files
                may be given separated by commas)
  DIFF:PREFIX   a `git diff --binary` and where its repository is in chromium/src
                (src.diff: for chromium/src itself, v8.diff:v8/, ...)

The rules, in order (the first that matches decides):
  - submodule pointer updates: dropped (the dependencies' own diffs carry their changes)
  - DEPS: dropped (not used by the build); chrome/VERSION with --branch-fixes: dropped
  - files neither in the tree nor added: dropped (not in the tarball)
  - translations other than en-GB (Chromium's .xtb files, DevTools' locale files other than
    en-US, en-XL and en-GB): dropped
  - Chrome's and V8's PGO profile pointers, AFDO and orderfile pointers: dropped (the
    ebuild doesn't use upstream's profiles: chrome_pgo_phase=0, or its own with USE=pgo)
  - binary files: dropped, except BINARY_KEEP (which must come as git binary patches)
  - infra/ (Chromium's CI configuration): dropped
  - files a build reads: kept
  - tests, docs, other platforms (iOS, Android, ChromeOS, Mac, Windows, Fuchsia, ...): dropped
  - everything else: kept (to be safe)
"""
import collections
import os
import re
import sys

BINARY_KEEP = {"third_party/icu/common/icudtl.dat"}
TRANSLATION = re.compile(
    r"(?<!_en-GB)\.xtb$|/front_end/core/i18n/locales/(?!en-(US|XL|GB)\.json$)[^/]+\.json$")
PROFILES = re.compile(
    r"^chrome/build/[^/]*\.(pgo|afdo\.newest)\.txt$|orderfile|^v8/tools/builtins-pgo/profiles/")
IRRELEVANT = re.compile(
    r"(^|/)(ios|android|android_webview|test|tests|testing|test_data|testdata|web_tests|_agents)"
    r"(/|$)|_(unit|browser|interactive_ui|ui|api|perf|fuzz)?tests?\.(cc|mm|java|py|ts|js)$|"
    r"Test\.java$|\.(md|java|kt|mm)$|_fuzzer\.cc$")
PLATFORM = re.compile(
    r"(^|/)(ash|chromeos|chromecast|fuchsia|mac|win|d3d|d3d11|accelerated_widget_mac|updater)"
    r"(/|$)|_(mac|win|android|chromeos|ios|fuchsia)\.(cc|h|mm)$|CHROMEOS_LKGM$|"
    r"^tools/metrics/")


def decide(f, p, tree, inputs, branch_fixes):
    new = re.search(r"(?m)^--- /dev/null", p) is not None
    binary = "\nBinary files differ" in p or "\nGIT binary patch" in p
    if re.search(r"(?m)^index \S+ 160000|^\+Subproject commit", p):
        return None, "submodule pointer"
    if f == "DEPS" or (branch_fixes and f == "chrome/VERSION"):
        return None, "version/DEPS"
    if not new and f not in tree:
        return None, "not in the tarball"
    if TRANSLATION.search(f):
        return None, "translation"
    if PROFILES.search(f):
        return None, "upstream profile pointer (unused)"
    if binary:
        if f in BINARY_KEEP:
            if "GIT binary patch" not in p:
                sys.exit(f"{f}: needs a git binary patch (git diff --binary)")
            return True, "binary (kept)"
        return None, "binary (unused)"
    if f.startswith("infra/"):
        return None, "CI configuration"
    if f in inputs:
        return True, "build input"
    if IRRELEVANT.search(f):
        return None, "test/docs/other platform"
    if PLATFORM.search(f):
        return None, "other platform"
    return True, "other (kept to be safe)"


def main():
    args = sys.argv[1:]
    branch_fixes = args[:1] == ["--branch-fixes"]
    if branch_fixes:
        args = args[1:]
    if len(args) < 4:
        sys.exit(__doc__)
    out, tree_file, inputs_files = args[:3]
    tree = set(open(tree_file).read().split("\n"))
    inputs = set()
    for f in inputs_files.split(","):
        inputs |= set(open(f).read().split())
    os.makedirs(os.path.join(out, "kept"), exist_ok=True)
    stats = collections.Counter()
    with open(os.path.join(out, "report.tsv"), "w") as report:
        for arg in args[3:]:
            path, _, prefix = arg.partition(":")
            text = open(path, encoding="utf-8", errors="surrogateescape").read()
            kept = []
            for p in re.split(r"(?m)^(?=diff --git )", text):
                if not p.startswith("diff --git"):
                    continue
                f = prefix + re.match(r"diff --git a/(\S+)", p).group(1)
                keep, why = decide(f, p, tree, inputs, branch_fixes)
                stats[("keep: " if keep else "drop: ") + why] += 1
                report.write(f"{f}\t{'keep' if keep else 'drop'}\t{why}\n")
                if keep:
                    kept.append(p)
            with open(os.path.join(out, "kept", os.path.basename(path)), "w",
                      encoding="utf-8", errors="surrogateescape") as k:
                k.write("".join(kept))
    for k, v in sorted(stats.items()):
        print(f"{v:6}  {k}")


if __name__ == "__main__":
    main()
