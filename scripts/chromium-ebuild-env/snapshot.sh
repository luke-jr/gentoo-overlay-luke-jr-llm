#!/bin/bash
# snapshot.sh OUTDIR [CATEGORY/PACKAGE]: for every ebuild of the package (default
# www-client/chromium) in the luke-jr-llm repository, save its metadata and its environment after
# pkg_setup (all functions and variables) in OUTDIR, for compare.py. Run as root (ebuild(1)); the
# package's build dependencies must be installed, as pkg_setup checks them.
set -u
out=$1 pkg=${2:-www-client/chromium}
repo=$(portageq get_repo_path / luke-jr-llm) || exit 1
mkdir -p "${out}" || exit 1
# The same for every snapshot, as paths under it end up in variables (S, ...).
export PORTAGE_TMPDIR=/var/tmp/chromium-ebuild-env
mkdir -p "${PORTAGE_TMPDIR}" || exit 1
cd "${repo}/${pkg}" || exit 1
for e in *.ebuild; do
	v=${e%.ebuild}
	python3 -c '
import portage, sys
db = portage.db[portage.root]["porttree"].dbapi
keys = sorted(db._known_keys)
for k, val in zip(keys, db.aux_get(sys.argv[1], keys, mytree=sys.argv[2])):
    print(f"{k}={val}")' "${pkg%/*}/${v}" "${repo}" > "${out}/${v}.metadata" || exit 1
	ebuild "${e}" clean setup > "${out}/${v}.setup.log" 2>&1
	echo "${v}: setup exit $?"
	cp "${PORTAGE_TMPDIR}/portage/${pkg%/*}/${v}/temp/environment" "${out}/${v}.environment" || exit 1
	ebuild "${e}" clean > /dev/null 2>&1
	# What the environment defines, without running any of it.
	env -i /bin/bash --norc --noprofile -c 'source "$1" >/dev/null 2>&1; declare -f' _ \
		"${out}/${v}.environment" > "${out}/${v}.functions"
	env -i /bin/bash --norc --noprofile -c 'source "$1" >/dev/null 2>&1; declare -p' _ "${out}/${v}.environment" |
		grep -vE '^declare -[-a-zA-Z]* (BASH[A-Z_]*|PPID|SHELLOPTS|_|RANDOM|SECONDS|EPOCH[A-Z]*|SRANDOM|LINENO|PWD|OLDPWD|HISTCMD|SHLVL|PIPESTATUS|FUNCNAME|GROUPS|EUID|UID|HOSTNAME|HOSTTYPE|MACHTYPE|OSTYPE|IFS|PS4|OPTIND|OPTERR|COLUMNS|LINES|DIRSTACK)=' \
		> "${out}/${v}.variables"
done
