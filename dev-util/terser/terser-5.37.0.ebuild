# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Terser's library bundle (what the npm package ships as dist/bundle.min.js),
# built from source: terser's main.js and lib/, plus @jridgewell/source-map and
# the packages it bundles, from their TypeScript. Chromium minifies WebUI and
# Mojo JavaScript with the npm package's prebuilt bundle; the Chromium ebuild
# uses this instead. Terser's own CLI (bin/terser) and the rest of the npm
# package are hand-written source, and are used from Chromium's tree.
#
# Slotted by version; consumers pin it exactly.

# name, version, GitHub repository, tag, and the source file that is the
# package's entry point.
TERSER_JS_DEPS=(
	"@jridgewell/gen-mapping 0.3.3 jridgewell/gen-mapping v0.3.3 src/gen-mapping.ts"
	"@jridgewell/resolve-uri 3.1.1 jridgewell/resolve-uri v3.1.1 src/resolve-uri.ts"
	"@jridgewell/set-array 1.1.2 jridgewell/set-array v1.1.2 src/set-array.ts"
	"@jridgewell/source-map 0.3.5 jridgewell/source-map v0.3.5 src/source-map.ts"
	"@jridgewell/sourcemap-codec 1.4.15 jridgewell/sourcemap-codec v1.4.15 src/sourcemap-codec.ts"
	"@jridgewell/trace-mapping 0.3.19 jridgewell/trace-mapping v0.3.19 src/trace-mapping.ts"
)

inherit edo

DESCRIPTION="Terser's JavaScript minifier library bundle, built from source"
HOMEPAGE="https://terser.org/ https://github.com/terser/terser"
SRC_URI="https://github.com/terser/terser/archive/refs/tags/v${PV}.tar.gz -> terser-${PV}.gh.tar.gz"
_terser_js_dep() {
	read -r dep_name dep_ver dep_repo dep_tag dep_entry <<< "${1}"
	# @scope/name -> scope-name, for the distfile
	dep_distfile="${dep_name#@}"
	dep_distfile="${dep_distfile//\//-}-${dep_ver}.gh.tar.gz"
	# GitHub's archive directory: repository name, tag without a leading "v"
	dep_dir="${dep_repo##*/}-${dep_tag#v}"
}
for _dep in "${TERSER_JS_DEPS[@]}"; do
	_terser_js_dep "${_dep}"
	SRC_URI+=" https://github.com/${dep_repo}/archive/refs/tags/${dep_tag}.tar.gz -> ${dep_distfile}"
done
unset _dep dep_name dep_ver dep_repo dep_tag dep_entry dep_distfile dep_dir

LICENSE="BSD-2 MIT"
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="net-libs/nodejs"
BDEPEND="
	dev-util/esbuild
	test? ( net-libs/nodejs )
"

src_compile() {
	# Like upstream's rollup.config.js (main.js as CommonJS), but with
	# @jridgewell/source-map included instead of external. acorn is only used
	# by the CLI's --parse acorn.
	local esbuild
	esbuild=$(best_version -b dev-util/esbuild) || die "dev-util/esbuild not found"
	esbuild="${BROOT}/usr/bin/esbuild-$(ver_cut 1-3 "${esbuild#dev-util/esbuild-}")"
	local args=(
		main.js --bundle --platform=node --format=cjs --target=node18
		--outfile="${WORKDIR}/terser.js" --log-level=warning --external:acorn
	)
	local _dep dep_name dep_ver dep_repo dep_tag dep_entry dep_distfile dep_dir
	for _dep in "${TERSER_JS_DEPS[@]}"; do
		_terser_js_dep "${_dep}"
		[[ -f ${WORKDIR}/${dep_dir}/${dep_entry} ]] || die "${dep_name}: ${dep_entry} not found"
		args+=( --alias:"${dep_name}=${WORKDIR}/${dep_dir}/${dep_entry}" )
	done
	edo "${esbuild}" "${args[@]}"
}

src_test() {
	# Upstream's test suite needs mocha; check that the bundle minifies, with a
	# source map (the @jridgewell/source-map part).
	node -e '
		const terser = require(process.argv[1]);
		terser.minify("function add(first, second) { return first + second; }",
		              { sourceMap: true }).then((r) => {
			if (r.code !== "function add(n,d){return n+d}") process.exit(1);
			if (!JSON.parse(r.map).mappings) process.exit(2);
		}, () => process.exit(3));
	' "${WORKDIR}/terser.js" || die "terser smoke test failed"
}

src_install() {
	insinto "/usr/lib/${PN}/${PV}"
	doins "${WORKDIR}/terser.js"
	dodoc README.md
}
