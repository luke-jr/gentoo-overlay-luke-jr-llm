#!/bin/bash
# fetchdiff.sh NAME URL OLDREV NEWREV
# Writes $PWD/NAME.diff: `git diff --binary` of the repository at URL between the two revisions
# (paths relative to the repository), from a blobless depth-1 fetch kept in $PWD/repo-NAME.
set -e
name=$1 url=$2 old=$3 new=$4 out=$PWD
mkdir -p "repo-${name}"
cd "repo-${name}"
[[ -d .git ]] || git init -q
git fetch -q --filter=blob:none --depth=1 "${url}" "+${old}:refs/x/old" "+${new}:refs/x/new"
git diff --binary refs/x/old refs/x/new > "${out}/${name}.diff"
echo "${name}: $(git diff --shortstat refs/x/old refs/x/new)"
