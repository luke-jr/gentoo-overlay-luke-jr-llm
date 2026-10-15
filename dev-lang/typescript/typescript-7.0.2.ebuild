# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# TypeScript 7, the compiler implemented in Go. It is developed in tsc/ of the
# TypeScript repository (formerly microsoft/typescript-go, now archived; its tag
# typescript/v7.0.2 == npm gitHead 2bd066d8 is byte-identical to tsc/ at v7.0.2).
#
# Slotted per exact version, beside TypeScript 6 (6.x here; ::gentoo's slot 0 is
# the npm package, with /usr/bin/tsc), which also has the JS API that TypeScript 7
# does not provide. Chromium 156 builds all of its TypeScript (WebUI and DevTools)
# with exactly this version and its lib*.d.ts files (patched in Chromium's tree);
# upstream Chromium uses the prebuilt npm package @typescript/typescript-linux-x64.
#
# No vendor tarball is available, so dependencies use EGO_SUM. Only the
# modules whose packages are compiled into cmd/tsgo are listed (cf.
# `go version -m` on the upstream binary). The Go command loads the module
# graph lazily (go.mod says go >= 1.17), so the remaining go.mod entries
# (test- and tool-only: go-cmp, gotest.tools, moq, x/tools, ...) are never
# fetched for `go build`. go-module.eclass's `go mod tidy` in src_unpack
# needs those as well and fails non-fatally; that is expected and harmless.
EGO_SUM=(
	"github.com/go-json-experiment/json v0.0.0-20260623181947-01eb4420fa68"
	"github.com/go-json-experiment/json v0.0.0-20260623181947-01eb4420fa68/go.mod"
	"github.com/klauspost/cpuid/v2 v2.2.10"
	"github.com/klauspost/cpuid/v2 v2.2.10/go.mod"
	"github.com/mackerelio/go-osstat v0.2.7"
	"github.com/mackerelio/go-osstat v0.2.7/go.mod"
	"github.com/zeebo/xxh3 v1.1.0"
	"github.com/zeebo/xxh3 v1.1.0/go.mod"
	"golang.org/x/sync v0.21.0"
	"golang.org/x/sync v0.21.0/go.mod"
	"golang.org/x/sys v0.46.0"
	"golang.org/x/sys v0.46.0/go.mod"
	"golang.org/x/term v0.44.0"
	"golang.org/x/term v0.44.0/go.mod"
	"golang.org/x/text v0.38.0"
	"golang.org/x/text v0.38.0/go.mod"
)

inherit git-archive go-module
go-module_set_globals

DESCRIPTION="Superset of JavaScript with optional static typing (TypeScript 7, written in Go)"
HOMEPAGE="
	https://www.typescriptlang.org/
	https://github.com/microsoft/TypeScript/
"
# The commit tag v7.0.2 points to, checked against the tarball in src_unpack.
TS_COMMIT=1e4744d68260a7cb91b62b12edc3f6a2187faaf1
SRC_URI="
	https://github.com/microsoft/TypeScript/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.gh.tar.gz
	${EGO_SUM_SRC_URI}
"
S="${WORKDIR}/TypeScript-${PV}/tsc"

# TypeScript and the bundled lib*.d.ts: Apache-2.0; Go modules:
# go-json-experiment/json, golang.org/x/*: BSD; zeebo/xxh3: BSD-2;
# klauspost/cpuid: MIT; mackerelio/go-osstat: Apache-2.0
LICENSE="Apache-2.0 BSD BSD-2 MIT"
# Slotted by exact version: Chromium pins one release (see above).
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"

# go.mod: "go 1.26"
BDEPEND=">=dev-lang/go-1.26:="

src_unpack() {
	git-archive_verify ${P}.gh.tar.gz ${TS_COMMIT}
	go-module_src_unpack
}

src_compile() {
	# Same as upstream's release build (Herebyfile.mjs, buildTsgo() with
	# getReleaseBuildFlags()), minus -s -w (stripping is Portage's job):
	#   CGO_ENABLED=0 go build -trimpath -tags=noembed \
	#     -ldflags="-s -w -X .../internal/core.version=${PV}" ./cmd/tsgo
	# With the 'noembed' tag the lib*.d.ts files are not embedded; tsc loads
	# them from the directory of its own (symlink-resolved) executable, like
	# the npm package does. CGO_ENABLED=0 also matches upstream (cmd/tsgo
	# pulls in net, which would otherwise use the cgo resolver).
	CGO_ENABLED=0 ego build -trimpath -tags=noembed \
		-ldflags="-X github.com/microsoft/typescript-go/internal/core.version=${PV}" \
		-o tsc ./cmd/tsgo
}

src_test() {
	# Upstream's Go test suite needs the microsoft/TypeScript submodule and
	# test-only Go modules; smoke-test the compiler as it will be installed.
	local t="${T}/smoke"
	mkdir -p "${t}" || die
	cp tsc internal/bundled/libs/*.d.ts "${t}"/ || die
	cat > "${t}/test.ts" <<-EOF || die
		export const m: Map<string, number> = new Map([["a", 1]]);
		document.body.textContent = String(m.get("a") ?? 0);
	EOF
	[[ $("${t}"/tsc --version) == "Version ${PV}" ]] || die "unexpected tsc --version"
	"${t}"/tsc --strict --target es2022 --lib es2022,dom --declaration \
		--outDir "${t}/out" "${t}/test.ts" || die "tsc smoke test failed"
	[[ -f ${t}/out/test.js && -f ${t}/out/test.d.ts ]] || die "tsc emitted nothing"
}

src_install() {
	# Same layout as the npm package's lib/ directory: tsc plus lib*.d.ts.
	local dir="/usr/lib/${PN}/${PV}"
	exeinto "${dir}"
	doexe tsc
	insinto "${dir}"
	doins internal/bundled/libs/*.d.ts

	# tsc resolves the symlink before looking for its lib*.d.ts. Versioned name:
	# ::gentoo's TypeScript 6 owns /usr/bin/tsc.
	dosym -r "${dir}/tsc" "/usr/bin/tsc-${PV}"

	dodoc README.md NOTICE.txt
}
