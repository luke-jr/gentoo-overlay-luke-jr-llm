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
git diff --raw --no-renames refs/x/old refs/x/new | cut -f2 | sort > "${out}/${name}.changed"
python3 -I - "${out}/${name}.diff" "${out}/${name}.changed" <<'EOF'
import re, sys
diff, changed = open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read(), sys.argv[2]
sections = re.split(r"^(?=diff --git )", diff, flags=re.M)[1:]
paths, bad = set(), []
for s in sections:
    path = re.match(r"diff --git a/(\S+) b/", s).group(1)
    paths.add(path)
    # A section without hunks is fine for an empty file added or deleted, or a mode change.
    empty = re.search(r"^index (0+\.\.e69de29|e69de29\w*\.\.0+)\b", s, re.M)
    if "\n@@ " not in s and "GIT binary patch" not in s and not empty and "\nold mode " not in s:
        bad.append(path)
missing = [p for p in open(changed).read().split("\n") if p and p not in paths]
for p in missing:
    print(f"missing from Gitiles' diff: {p}", file=sys.stderr)
for p in bad:
    print(f"no content in Gitiles' diff (binary?): {p}", file=sys.stderr)
sys.exit(1 if missing or bad else 0)
EOF
echo "${name}: $(grep -c '^diff --git ' "${out}/${name}.diff") files changed"
