#!/bin/bash
# fetchdiff.sh NAME URL OLDREV NEWREV
# Writes $PWD/NAME.diff: the diff of the repository at URL (a Gitiles host) between the two
# revisions (paths relative to the repository), as Gitiles serves it: one request, no file contents
# downloaded. A blobless depth-1 fetch (trees only, kept in $PWD/repo-NAME) checks that the diff has
# every changed file, and lets the patched files be checked against the new tree's blob ids.
set -e
name=$1 url=$2 old=$3 new=$4 out=$PWD
mkdir -p "repo-${name}"
cd "repo-${name}"
[[ -d .git ]] || git init -q
git fetch -q --filter=blob:none --depth=1 "${url}" "+${old}:refs/x/old" "+${new}:refs/x/new"
old=$(git rev-parse refs/x/old) new=$(git rev-parse refs/x/new)

# Gitiles times out or fails now and then: retry.
for try in 1 2 3 4 5; do
	curl -sSf --max-time 600 "${url%.git}/+/${old}..${new}/?format=TEXT" | base64 -d > "${out}/${name}.diff" &&
		[[ -s ${out}/${name}.diff ]] && break
	[[ ${try} == 5 ]] && { echo "${name}: Gitiles' diff failed" >&2; exit 1; }
	sleep $((try * 10))
done

# Every changed path must be in the diff, with content (Gitiles leaves binary files' out).
# --raw needs only the trees.
python3 -I - "${out}/${name}.diff" <<'EOF'
import re, subprocess, sys
diff = open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read()
raw = subprocess.run(["git", "diff", "--raw", "-z", "--no-renames", "refs/x/old", "refs/x/new"],
                     check=True, capture_output=True).stdout.decode("utf-8", "surrogateescape").split("\0")
changed = [raw[i + 1] for i in range(0, len(raw) - 1, 2)]   # ":modes ids status", path, ...

def path(header):
    """The b/ path of a "diff --git" line: plain (maybe with spaces) or C-quoted."""
    rest = header[len("diff --git "):]
    if rest.startswith('"'):
        q = re.findall(r'"((?:[^"\\]|\\.)*)"', rest)[-1]
        q = q.encode("latin-1", "backslashreplace").decode("unicode_escape").encode("latin-1").decode("utf-8", "surrogateescape")
        return q[2:]
    n = (len(rest) - 5) // 2           # "a/" X " b/" X
    return rest[2:2 + n]

paths, bad = set(), []
for s in re.split(r"^(?=diff --git )", diff, flags=re.M)[1:]:
    p = path(s.split("\n", 1)[0])
    paths.add(p)
    # A section without hunks is fine for an empty file added or deleted, or a mode change.
    empty = re.search(r"^index (0+\.\.e69de29|e69de29\w*\.\.0+)\b", s, re.M)
    if "\n@@ " not in s and "GIT binary patch" not in s and not empty and "\nold mode " not in s:
        bad.append(p)
missing = [p for p in changed if p not in paths]
for p in missing:
    print(f"missing from Gitiles' diff: {p}", file=sys.stderr)
for p in bad:
    print(f"no content in Gitiles' diff (binary?): {p}", file=sys.stderr)
sys.exit(1 if missing or bad else 0)
EOF
echo "${name}: $(grep -c '^diff --git ' "${out}/${name}.diff") files changed"
