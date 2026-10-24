# Copyright 2018-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
PYTHON_COMPAT=( python3_{11..14} )

# The exact revision Chromium 157 pins in DEPS (gn_version).
# deps.gentoo.zip has no tarball for it and gitiles archives are not reproducible,
# so fetch the pinned commit with git-r3.
EGIT_REPO_URI="https://gn.googlesource.com/gn"
EGIT_COMMIT="0035961837fbcfe875d855744b3eda4fd2eefb43"

inherit edo git-r3 ninja-utils python-any-r1 toolchain-funcs

DESCRIPTION="GN is a meta-build system that generates build files for Ninja"
HOMEPAGE="https://gn.googlesource.com/"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
RESTRICT="test"

BDEPEND="
	${PYTHON_DEPS}
	app-alternatives/ninja
"

PATCHES=(
	"${FILESDIR}"/gn-gen-r8.patch
)

pkg_setup() {
	:
}

src_configure() {
	python_setup
	tc-export AR CC CXX
	unset CFLAGS
	set -- ${EPYTHON} build/gen.py --no-last-commit-position --no-strip --no-static-libstdc++ --allow-warnings
	edo "$@"
	cat >out/last_commit_position.h <<-EOF || die
	#ifndef OUT_LAST_COMMIT_POSITION_H_
	#define OUT_LAST_COMMIT_POSITION_H_
	#define LAST_COMMIT_POSITION_NUM ${PV##0.}
	#define LAST_COMMIT_POSITION "${PV}"
	#endif  // OUT_LAST_COMMIT_POSITION_H_
	EOF
}

src_compile() {
	eninja -C out gn
}

src_install() {
	dobin out/gn
	einstalldocs

	insinto /usr/share/vim/vimfiles
	doins -r misc/vim/{autoload,ftdetect,ftplugin,syntax}
}
