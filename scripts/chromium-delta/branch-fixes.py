#!/usr/bin/env python3
"""Make and check a *-branch-fixes.patch: a release branch's changes after a tag, up to its head.

Usage: branch-fixes.py [--head REV] WORK_DIR TAG TARBALL TREE_FILES BUILD_INPUTS [UPGRADE_PATCH...]
  WORK_DIR       a new or empty directory (outside the overlay): diffs, filter report, check
                 tree; the result is WORK_DIR/final.patch
  TAG            the release the patch applies to (159.0.8154.32); its branch is
                 refs/branch-heads/<third number>
  TARBALL        the base tarball (chromium-<version>[-lite|-linux].tar.xz)
  TREE_FILES     the files of the tree the patch applies to: the tarball's plus what the upgrade
                 patches add (README step 3; the same list for every refresh of one TAG)
  BUILD_INPUTS   as filter.py's (comma-separated)
  UPGRADE_PATCH  the patches that make TAG's tree from the tarball, in order (none when the
                 tarball is TAG's)
  --head REV     a branch commit to stop at instead of the branch's head

Steps (README "Making a patch", with --branch-fixes):
  1. DEPS at TAG and at the head: deps.py changed. A changed CIPD/GCS dependency, a change of
     gclient_args.gni, or an added or removed git dependency stops it: those need a decision.
  2. fetchdiff.sh for chromium/src (TAG..head) and each git dependency whose revision changed.
  3. filter.py --branch-fixes.
  4. The kept diffs, with their prefixes, under a header naming the range and every commit
     that touches a kept file (chromium/src commits, and the dependency rolls and dependency
     commits behind kept dependency files), with their branch positions.
  5. Checks: the patch applies to TAG's tree (the patched files taken from the tarball, with
     the upgrade patches' sections for them applied), and every patched file is
     byte-identical to its version at the head (or the dependency's new revision);
     deleted files are gone.

Prints the newest kept change's position N (the ebuild is <TAG>_p<N>_pre) and the commits.
"""
import base64
import json
import os
import re
import subprocess
import sys
import textwrap
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "https://chromium.googlesource.com/chromium/src"
NAMES = {"v8": "V8", "third_party/angle": "ANGLE", "third_party/dawn": "Dawn",
         "third_party/skia": "Skia"}


def die(msg):
    sys.exit(f"branch-fixes.py: {msg}")


def fetch(url):
    for t in range(5):
        try:
            return urllib.request.urlopen(url, timeout=300).read()
        except OSError:
            if t == 4:
                raise
            time.sleep(10 * (t + 1))


def gitiles_json(url):
    return json.loads(fetch(url).decode().split("\n", 1)[1])


def log(repo, rng):
    """Commits of the range, newest first, with their changed paths."""
    out, tok = [], None
    while True:
        d = gitiles_json(f"{repo}/+log/{rng}?format=JSON&name-status=1&n=500"
                         + (f"&s={tok}" if tok else ""))
        out += d["log"]
        tok = d.get("next")
        if not tok:
            return out


def position(msg):
    m = re.findall(r"^Cr-Commit-Position: refs/branch-heads/\d+@\{#(\d+)\}$", msg, re.M)
    return int(m[-1]) if m else None


def paths(c):
    return {p for t in c["tree_diff"] for p in (t.get("old_path"), t.get("new_path"))
            if p and p != "/dev/null"}


def diff_paths(text):
    """(a path, b path) of every section of a git diff (renames from their own lines)."""
    out = []
    for sec in re.split(r"^(?=diff --git )", text, flags=re.M):
        if not sec.startswith("diff --git "):
            continue
        rest = sec.splitlines()[0][len("diff --git "):]
        if rest.startswith('"'):
            die(f"quoted path, not handled: {rest}")
        n = (len(rest) - 5) // 2
        a, b = rest[2:2 + n], rest[2 + n + 3:]
        m1 = re.search(r"^(?:rename|copy) from (.*)$", sec, re.M)
        m2 = re.search(r"^(?:rename|copy) to (.*)$", sec, re.M)
        if m1 and m2:
            a, b = m1.group(1), m2.group(1)
        out.append((a, b, sec))
    return out


def prefixed(text, pre):
    """A dependency's diff with its paths under PRE (as tools/prefix.py in earlier work dirs)."""
    out = []
    for line in text.split("\n"):
        if line.startswith("diff --git "):
            a, b, _ = diff_paths(line + "\n")[0]
            line = f"diff --git a/{pre}{a} b/{pre}{b}"
        elif line.startswith(("--- a/", "+++ b/")):
            line = line[:6] + pre + line[6:]
        elif re.match(r"^(rename|copy) (from|to) ", line):
            x, y, z = line.split(" ", 2)
            line = f"{x} {y} {pre}{z}"
        out.append(line)
    return "\n".join(out)


def run(*args, **kw):
    return subprocess.run(args, check=True, **kw)


def main():
    argv = sys.argv[1:]
    head = None
    if argv[:1] == ["--head"]:
        head, argv = argv[1], argv[2:]
    if len(argv) < 5:
        sys.exit(__doc__)
    work, tag, tarball, tree_files, inputs = argv[:5]
    upgrades = [os.path.abspath(p) for p in argv[5:]]
    tarball, tree_files = os.path.abspath(tarball), os.path.abspath(tree_files)
    inputs = ",".join(os.path.abspath(p) for p in inputs.split(","))
    branch = tag.split(".")[2]
    m = re.match(r"(chromium-[0-9.]+?)(?:-lite|-linux)?\.tar\.xz$", os.path.basename(tarball))
    if not m:
        die(f"not a chromium tarball name: {tarball}")
    top = m.group(1)
    os.makedirs(work, exist_ok=True)
    os.chdir(work)
    if os.listdir("."):
        die(f"{work} is not empty")

    # 1. The head, and the dependencies that changed.
    if head is None:
        head = run("git", "ls-remote", SRC, f"refs/branch-heads/{branch}",
                   capture_output=True, text=True).stdout.split()[0]
    hc = gitiles_json(f"{SRC}/+/{head}?format=JSON")
    head, head_pos = hc["commit"], position(hc["message"])
    if head_pos is None:
        die(f"{head} is not on refs/branch-heads/{branch}")
    if gitiles_json(f"{SRC}/+/refs/tags/{tag}?format=JSON")["commit"] == head:
        die(f"the branch has nothing after {tag}: no patch needed")
    for name, rev in (("DEPS.tag", f"refs/tags/{tag}"), ("DEPS.head", head)):
        with open(name, "wb") as f:
            f.write(base64.b64decode(fetch(f"{SRC}/+/{rev}/DEPS?format=TEXT")))
    changed = run(sys.executable, "-I", f"{HERE}/deps.py", "changed", "DEPS.tag", "DEPS.head",
                  capture_output=True, text=True).stdout.splitlines()
    deps = []
    for line in changed:
        f = line.split()
        if f[0] in ("nongit", "gclient_gn_args") or "new" in f[2:] or "gone" in f[2:]:
            die(f"needs a decision (README step 1): {line}")
        deps.append((f[0], f[1], f[2], f[3]))    # path, url, old, new

    # 2. The diffs.
    diffs = [("src", "", SRC, f"refs/tags/{tag}", head)]
    for path, url, old, new in deps:
        diffs.append((path.replace("/", "_"), path + "/", url, old, new))
    for name, _, url, old, new in diffs:
        run(f"{HERE}/fetchdiff.sh", name, url, old, new)

    # 3. Filter.
    run(sys.executable, "-I", f"{HERE}/filter.py", "--branch-fixes", "out", tree_files, inputs,
        *(f"{name}.diff:{pre}" for name, pre, *_ in diffs), stdout=open("filter.out", "w"))
    body, kept = "", {}
    for name, pre, *_ in diffs:
        text = open(f"out/kept/{name}.diff", encoding="utf-8", errors="surrogateescape").read()
        kept[name] = {p for a, b, _ in diff_paths(text) for p in (a, b)}
        body += prefixed(text, pre) if pre else text
    if not body:
        die(f"nothing kept up to {head} ({branch}@{{#{head_pos}}}): no patch needed")

    # 4. The commits behind the kept files, and the header.
    src_log = log(SRC, f"refs/tags/{tag}..{head}")
    contrib, dep_lines, rolls = [], [], {}
    for name, pre, url, old, new in diffs[1:]:
        if not kept[name]:
            continue
        path = pre[:-1]
        label = NAMES.get(path, path)
        for c in log(url.removesuffix(".git"), f"{old}..{new}")[::-1]:
            touched = sorted(paths(c) & kept[name])
            if touched:
                dep_lines.append(f"  {c['commit'][:12]} {c['message'].splitlines()[0]}"
                                 f" ({label}: {', '.join(touched)})")
        for c in src_log:
            for t in c["tree_diff"]:
                if t.get("new_path") == path and t.get("new_mode") == 0o160000:
                    rolls[c["commit"]] = f"{label} {t['old_id'][:12]}..{t['new_id'][:12]}"
    for c in src_log[::-1]:
        pos = position(c["message"])
        subject = c["message"].splitlines()[0]
        if c["commit"] in rolls:
            contrib.append((pos, f"  {c['commit'][:12]} {subject} ({rolls[c['commit']]}, "
                                 f"{branch}@{{#{pos}}})"))
        elif paths(c) & kept["src"]:
            contrib.append((pos, f"  {c['commit'][:12]} {subject} ({branch}@{{#{pos}}})"))
    if not contrib:
        die("kept files, but no commit of the range touches them")
    n = max(p for p, _ in contrib)
    kept_deps = [(NAMES.get(pre[:-1], pre[:-1]), old, new, pre)
                 for name, pre, url, old, new in diffs[1:] if kept[name]]
    if kept_deps:
        which = ", ".join(f"{label} {old[:12]}..{new[:12]} (under {pre})"
                          for label, old, new, pre in kept_deps)
        deps_text = (f"and the dependenc{'y' if len(kept_deps) == 1 else 'ies'} whose DEPS "
                     f"revision changed: {which}")
    else:
        deps_text = "(no dependency's DEPS revision changes with kept files)"
    others = [NAMES.get(p, p) for p, *_ in deps if p + "/" not in {d[3] for d in kept_deps}]
    upgrade_names = ", ".join(os.path.basename(p) for p in upgrades) or "none"
    fill = lambda text: textwrap.fill(" ".join(text.split()), width=92)
    paragraphs = [
        f"""Chromium {tag} + the later changes of its release branch, up to {head}
        (refs/branch-heads/{branch}@{{#{head_pos}}}), for the {tag} tree (the
        {os.path.basename(tarball)} tarball, upgrade patches: {upgrade_names}). The newest
        change it carries is {branch}@{{#{n}}}.""",
        f"""Generated from the upstream diffs chromium/src refs/tags/{tag}..{head[:12]}
        {deps_text}, as served by Gitiles, with scripts/chromium-delta/branch-fixes.py
        (filter.py --branch-fixes, against the {tag} tree's files): left out are files not in
        the release tarball, iOS/Android/ChromeOS/Mac/Windows-only files, tests and docs (GN
        files kept), translations other than en-GB, PGO/orderfile/AFDO pointers, submodule
        pointer updates. chrome/VERSION (the branch's "Incrementing VERSION" commits after the
        {tag} tag are not tags yet), the DEPS files and the stamp files stay at {tag}."""
        + (" Dependencies whose revision changed with nothing kept: " + ", ".join(others)
           + "." if others else ""),
    ]
    header = "\n\n".join(fill(x) for x in paragraphs) + "\n\n"
    header += "Commits contributing to it (oldest first):\n" + \
        "\n".join(line for _, line in contrib) + "\n"
    if dep_lines:
        header += "Dependency commits of those rolls that touch kept files:\n" + \
            "\n".join(dep_lines) + "\n"
    header += "\n" + fill(
        f"""Checked: applies to the {tag} tree; every patched file is byte-identical to its
        version at {head[:12]}"""
        + "".join(f" (or {label}'s {new[:12]})" for label, old, new, pre in kept_deps)
        + ".") + "\n\nApply with git apply.\n\n"
    with open("final.patch", "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write(header + body)

    # 5. Checks, in a tree of only the patched files.
    secs = diff_paths(body)
    members = {p for a, b, _ in secs for p in (a, b)}
    up_secs = [s for p in upgrades for s in diff_paths(
        open(p, encoding="utf-8", errors="surrogateescape").read())]
    # A patched file's base: the tarball's file (the upgrade section's source, for a rename),
    # with the upgrade patches' section for it applied; or the tarball's file as it is.
    sel = [(a, b, sec) for a, b, sec in up_secs if b in members]
    tree = set(open(tree_files).read().split("\n"))
    need = {a for a, b, sec in sel if not re.search(r"^new file mode", sec, re.M)}
    need |= {p for p in members if p in tree and p not in {b for a, b, _ in sel}}
    os.makedirs("chk")
    if need:
        with open("extract.txt", "w") as f:
            f.write("".join(f"{top}/{p}\n" for p in sorted(need)))
        run("tar", "-I", "pixz", "-xf", tarball, "-C", "chk", "-T", "extract.txt")
    t = f"chk/{top}"
    os.makedirs(t, exist_ok=True)
    git = ["git", "-C", t]
    run(*git, "init", "-q")
    if sel:
        with open("upgrade-sel.patch", "w", encoding="utf-8", errors="surrogateescape") as f:
            f.write("".join(sec for a, b, sec in sel))
        run(*git, "apply", os.path.abspath("upgrade-sel.patch"))
    run(*git, "add", "-A")
    run(*git, "-c", "user.name=x", "-c", "user.email=x@x", "commit", "-q", "--allow-empty",
        "-m", "base")
    run(*git, "apply", os.path.abspath("final.patch"))
    bad = 0
    repos = sorted(((pre, f"repo-{name}") for name, pre, *_ in diffs),
                   key=lambda x: -len(x[0]))
    for a, b, sec in secs:
        gone = bool(re.search(r"^deleted file mode", sec, re.M))
        f = os.path.join(t, b)
        if gone:
            if os.path.lexists(f):
                print(f"NOT DELETED {b}")
                bad += 1
            continue
        pre, repo = next((pre, repo) for pre, repo in repos if b.startswith(pre))
        want = subprocess.run(["git", "-C", repo, "rev-parse", f"refs/x/new:{b[len(pre):]}"],
                              capture_output=True, text=True).stdout.strip()
        have = run("git", "hash-object", f, capture_output=True, text=True).stdout.strip()
        if want != have:
            print(f"DIFFERS {b}")
            bad += 1
    if bad:
        die(f"{bad} patched files differ from upstream: {work}/final.patch is wrong")

    print(f"head {head} ({branch}@{{#{head_pos}}}); newest kept change {branch}@{{#{n}}}: "
          f"{tag}_p{n}_pre")
    print(f"{len(secs)} files, applied and byte-checked; commits:")
    print("\n".join(line for _, line in contrib))
    if dep_lines:
        print("\n".join(dep_lines))
    print(f"result: {os.path.abspath('final.patch')}")


main()
