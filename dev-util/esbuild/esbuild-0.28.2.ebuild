# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Chromium 156 needs this exact version (devtools-frontend checks it).
# No vendor tarball exists on deps.gentoo.zip for this version, but esbuild
# has exactly one dependency, pinned for Go 1.13 compatibility, so EGO_SUM
# is simple here.
EGO_SUM=(
	"golang.org/x/sys v0.0.0-20220715151400-c0bba94af5f8"
	"golang.org/x/sys v0.0.0-20220715151400-c0bba94af5f8/go.mod"
)

inherit git-archive go-module
go-module_set_globals

DESCRIPTION="A modern, extremely fast, JavaScript and CSS bundler and minifier"
HOMEPAGE="https://esbuild.github.io/"
# The commit tag v0.28.2 points to, checked against the tarball in src_unpack.
ESBUILD_COMMIT=609683d892977362a0f99026cb74b96263d728a9
SRC_URI="https://github.com/evanw/esbuild/archive/v${PV}.tar.gz -> ${P}.tar.gz
	${EGO_SUM_SRC_URI}"

LICENSE="BSD MIT"
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"

RESTRICT="test" # tests require more work, but chromium needs esbuild already.

src_unpack() {
	git-archive_verify ${P}.tar.gz ${ESBUILD_COMMIT}
	go-module_src_unpack
}

src_compile() {
	ego build -v -ldflags="-s -w" ./cmd/esbuild
}

src_install() {
	newbin esbuild esbuild-${PV}
}
