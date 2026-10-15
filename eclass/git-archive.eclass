# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: git-archive.eclass
# @MAINTAINER:
# luke-jr-llm overlay
# @SUPPORTED_EAPIS: 8 9
# @BLURB: verify the commit a forge's source tarball was made from
# @DESCRIPTION:
# GitHub, GitLab, Forgejo (Codeberg) and cgit make their source tarballs with
# git archive, which records the commit ID in a pax global header. A tag can
# be moved, and a tarball fetched by tag is otherwise only pinned by its
# Manifest checksum; git-archive_verify checks that a tarball was made from
# the expected commit, so the ebuild names the exact source revision it was
# reviewed against.
#
# @EXAMPLE:
# @CODE
# SRC_URI="https://github.com/foo/bar/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"
# BAR_COMMIT=0123456789abcdef0123456789abcdef01234567 # v${PV}
#
# src_unpack() {
# 	git-archive_verify "${P}.gh.tar.gz" "${BAR_COMMIT}"
# 	default
# }
# @CODE

case ${EAPI} in
	8|9) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_GIT_ARCHIVE_ECLASS} ]]; then
_GIT_ARCHIVE_ECLASS=1

# @FUNCTION: git-archive_commit
# @USAGE: <archive>
# @DESCRIPTION:
# Print the commit ID git archive recorded in <archive> (a path, or a file
# name in DISTDIR); .tar.gz, .tgz, .tar.bz2 and .tar.xz. Dies if it has none.
git-archive_commit() {
	local f=${1}
	[[ ${f} == */* ]] || f=${DISTDIR}/${f}
	local -a cat
	case ${f} in
		*.tar.gz|*.tgz) cat=( gzip -dc ) ;;
		*.tar.bz2) cat=( bzip2 -dc ) ;;
		*.tar.xz) cat=( xz -dc ) ;;
		*) die "${FUNCNAME}: unsupported archive ${f}" ;;
	esac
	# the first header block is the pax global header (type g), whose
	# record is "52 comment=<40 hex digits>\n"
	local type record
	type=$("${cat[@]}" -- "${f}" 2>/dev/null | head -c 157 | tail -c 1)
	record=$("${cat[@]}" -- "${f}" 2>/dev/null | head -c 564 | tail -c 52)
	if [[ ${type} != g || ! ${record} =~ ^"52 comment="([0-9a-f]{40})$ ]]; then
		die "${FUNCNAME}: ${f##*/} has no git archive commit ID"
	fi
	echo "${BASH_REMATCH[1]}"
}

# @FUNCTION: git-archive_verify
# @USAGE: <archive> <commit> [<archive> <commit>]...
# @DESCRIPTION:
# Die unless each <archive> was made from <commit> (a full 40-digit ID).
git-archive_verify() {
	(( $# && $# % 2 == 0 )) || die "${FUNCNAME}: needs archive/commit pairs"
	local got
	while (( $# )); do
		[[ ${2} =~ ^[0-9a-f]{40}$ ]] || die "${FUNCNAME}: ${1}: not a full commit ID: ${2}"
		got=$(git-archive_commit "${1}") || die
		[[ ${got} == "${2}" ]] ||
			die "${FUNCNAME}: ${1##*/} was made from commit ${got}, expected ${2}"
		shift 2
	done
}

fi
