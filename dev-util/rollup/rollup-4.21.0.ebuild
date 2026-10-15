# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# The Rollup bundler, built from source: the command-line tool (rollup's
# TypeScript and the npm packages its own build bundles in, bundled with
# esbuild) and its JavaScript parser (SWC-based, Rust) as a native Node.js
# addon. Chromium bundles WebUI resources and chromium-bidi with the npm package
# @rollup/wasm-node, i.e. generated JavaScript and a prebuilt WebAssembly
# parser; the Chromium ebuild uses this instead. The addon is rollup's own napi
# binding (rust/bindings_napi, what the regular "rollup" npm package ships as
# @rollup/rollup-<platform>).
#
# Not included: watch mode (--watch), which would need chokidar and its
# dependencies, and the JavaScript API (import "rollup").
#
# The parser's binary AST format belongs to one rollup release, so this is
# slotted by version and consumers pin it exactly.

# npm packages that rollup's own build bundles into its CLI (versions from its
# package-lock.json): name, version, GitHub repository, tag, and the source file
# that is the package's entry point.
ROLLUP_JS_DEPS=(
	"@jridgewell/sourcemap-codec 1.5.0 jridgewell/sourcemap-codec v1.5.0 src/sourcemap-codec.ts"
	"@rollup/pluginutils 5.1.0 rollup/plugins pluginutils-v5.1.0 packages/pluginutils/src/index.ts"
	"builtin-modules 4.0.0 sindresorhus/builtin-modules v4.0.0 index.js"
	"colorette 2.0.20 jorgebucaran/colorette 2.0.20 index.js"
	"date-time 4.0.0 sindresorhus/date-time v4.0.0 index.js"
	"estree-walker 2.0.2 Rich-Harris/estree-walker v2.0.2 src/index.js"
	"flru 1.0.2 lukeed/flru v1.0.2 src/index.js"
	"is-reference 3.0.2 Rich-Harris/is-reference v3.0.2 src/index.js"
	"locate-character 3.0.0 Rich-Harris/locate-character v3.0.0 src/index.js"
	"magic-string 0.30.11 Rich-Harris/magic-string v0.30.11 src/index.js"
	"parse-ms 4.0.0 sindresorhus/parse-ms v4.0.0 index.js"
	"picomatch 2.3.1 micromatch/picomatch 2.3.1 index.js"
	"pretty-bytes 6.1.1 sindresorhus/pretty-bytes v6.1.1 index.js"
	"pretty-ms 9.1.0 sindresorhus/pretty-ms v9.1.0 index.js"
	"signal-exit 4.1.0 tapjs/signal-exit v4.1.0 src/index.ts"
	"time-zone 2.0.0 sindresorhus/time-zone v2.0.0 index.js"
	"yargs-parser 21.1.1 yargs/yargs-parser yargs-parser-v21.1.1 lib/index.ts"
)

# The parser's Cargo.lock, minus CARGO_STUB_CRATES
CRATES="
	ahash@0.8.11
	aho-corasick@1.1.3
	allocator-api2@0.2.18
	anyhow@1.0.86
	arrayvec@0.7.4
	ast_node@0.9.9
	autocfg@1.3.0
	base-encode@0.3.1
	base64@0.21.7
	base64-simd@0.7.0
	better_scoped_tls@0.1.1
	bitflags@2.6.0
	bitvec@1.0.1
	bumpalo@3.16.0
	cc@1.1.12
	cfg-if@1.0.0
	convert_case@0.6.0
	ctor@0.2.8
	cty@0.2.2
	dashmap@5.5.3
	data-encoding@2.6.0
	debugid@0.8.0
	either@1.13.0
	equivalent@1.0.1
	fixedbitset@0.4.2
	form_urlencoded@1.2.1
	from_variant@0.1.9
	funty@2.0.0
	getrandom@0.2.15
	hashbrown@0.14.5
	hstr@0.2.12
	idna@0.5.0
	if_chain@1.0.2
	indexmap@2.4.0
	Inflector@0.11.4
	is-macro@0.3.6
	itoa@1.0.11
	js-sys@0.3.70
	libc@0.2.156
	lock_api@0.4.12
	log@0.4.22
	memchr@2.7.4
	mimalloc-rust@0.2.1
	mimalloc-rust-sys@1.7.9-source
	napi@2.16.9
	napi-build@2.1.3
	napi-derive@2.16.11
	napi-derive-backend@1.0.73
	napi-sys@2.4.0
	new_debug_unreachable@1.0.6
	num-bigint@0.4.6
	num-integer@0.1.46
	num-traits@0.2.19
	num_cpus@1.16.0
	once_cell@1.19.0
	outref@0.1.0
	parking_lot@0.12.3
	parking_lot_core@0.9.10
	pathdiff@0.2.1
	percent-encoding@2.3.1
	petgraph@0.6.5
	phf@0.11.2
	phf_generator@0.11.2
	phf_macros@0.11.2
	phf_shared@0.11.2
	pin-project-lite@0.2.14
	proc-macro2@1.0.86
	psm@0.1.21
	ptr_meta@0.1.4
	ptr_meta_derive@0.1.4
	quote@1.0.36
	radium@0.7.0
	radix_fmt@1.0.0
	rand@0.8.5
	rand_core@0.6.4
	regex@1.10.6
	regex-automata@0.4.7
	regex-syntax@0.8.4
	rustc-hash@1.1.0
	rustc_version@0.2.3
	ryu@1.0.18
	ryu-js@1.0.1
	scoped-tls@1.0.1
	scopeguard@1.2.0
	semver@0.9.0
	semver@1.0.23
	semver-parser@0.7.0
	serde@1.0.208
	serde_derive@1.0.208
	serde_json@1.0.125
	shlex@1.3.0
	simd-abstraction@0.7.1
	siphasher@0.3.11
	smallvec@1.13.2
	smartstring@1.0.1
	sourcemap@9.0.0
	stable_deref_trait@1.2.0
	stacker@0.1.15
	static_assertions@1.1.0
	string_enum@0.4.4
	swc_allocator@0.1.8
	swc_atoms@0.6.7
	swc_cached@0.3.20
	swc_common@0.37.2
	swc_compiler_base@0.16.0
	swc_config@0.1.15
	swc_config_macro@0.1.4
	swc_ecma_ast@0.118.1
	swc_ecma_codegen@0.155.0
	swc_ecma_codegen_macros@0.7.7
	swc_ecma_minifier@0.201.0
	swc_ecma_parser@0.149.0
	swc_ecma_transforms_base@0.144.0
	swc_ecma_transforms_macros@0.5.5
	swc_ecma_transforms_optimization@0.205.0
	swc_ecma_usage_analyzer@0.30.0
	swc_ecma_utils@0.134.1
	swc_ecma_visit@0.104.5
	swc_eq_ignore_macros@0.1.4
	swc_fast_graph@0.25.0
	swc_macros_common@0.3.13
	swc_timer@0.25.0
	swc_visit@0.6.2
	syn@1.0.109
	syn@2.0.74
	tap@1.0.1
	tinyvec@1.8.0
	tinyvec_macros@0.1.1
	tracing@0.1.40
	tracing-attributes@0.1.27
	tracing-core@0.1.32
	triomphe@0.1.13
	typed-arena@2.0.2
	unicode-bidi@0.3.15
	unicode-id@0.3.4
	unicode-id-start@1.2.0
	unicode-ident@1.0.12
	unicode-normalization@0.1.23
	unicode-segmentation@1.11.0
	unicode-width@0.1.13
	url@2.5.2
	uuid@1.10.0
	version_check@0.9.5
	wasm-bindgen@0.2.93
	wasm-bindgen-backend@0.2.93
	wasm-bindgen-macro@0.2.93
	wasm-bindgen-macro-support@0.2.93
	wasm-bindgen-shared@0.2.93
	wyz@0.5.1
	xxhash-rust@0.8.12
	zerocopy@0.7.35
"

# Never built on Linux (see cargo-stubs.eclass).
CARGO_STUB_CRATES="
	hermit-abi@0.3.9
	libloading@0.8.5
	redox_syscall@0.5.3
	wasi@0.11.0+wasi-snapshot-preview1
	winapi@0.3.9
	winapi-i686-pc-windows-gnu@0.4.0
	winapi-x86_64-pc-windows-gnu@0.4.0
	windows-targets@0.52.6
	windows_aarch64_gnullvm@0.52.6
	windows_aarch64_msvc@0.52.6
	windows_i686_gnu@0.52.6
	windows_i686_gnullvm@0.52.6
	windows_i686_msvc@0.52.6
	windows_x86_64_gnu@0.52.6
	windows_x86_64_gnullvm@0.52.6
	windows_x86_64_msvc@0.52.6
	zerocopy-derive@0.7.35
"

PYTHON_COMPAT=( python3_{12..15} )

inherit cargo cargo-stubs edo flag-o-matic

DESCRIPTION="The Rollup JavaScript bundler, built from source (CLI and native parser)"
HOMEPAGE="https://rollupjs.org/ https://github.com/rollup/rollup"
SRC_URI="
	https://github.com/rollup/rollup/archive/refs/tags/v${PV}.tar.gz -> rollup-${PV}.gh.tar.gz
	${CARGO_CRATE_URIS}
"
_rollup_js_dep() {
	read -r dep_name dep_ver dep_repo dep_tag dep_entry <<< "${1}"
	# @scope/name -> scope-name, for the distfile
	dep_distfile="${dep_name#@}"
	dep_distfile="${dep_distfile//\//-}-${dep_ver}.gh.tar.gz"
	# GitHub's archive directory: repository name, tag without a leading "v"
	dep_dir="${dep_repo##*/}-${dep_tag#v}"
}
for _dep in "${ROLLUP_JS_DEPS[@]}"; do
	_rollup_js_dep "${_dep}"
	SRC_URI+=" https://github.com/${dep_repo}/archive/refs/tags/${dep_tag}.tar.gz -> ${dep_distfile}"
done
unset _dep dep_name dep_ver dep_repo dep_tag dep_entry dep_distfile dep_dir
S="${WORKDIR}/rollup-${PV}/rust"

LICENSE="MIT"
# Bundled npm packages
LICENSE+=" ISC"
# Dependent crate licenses
LICENSE+=" Apache-2.0 BSD BSD-2 Boost-1.0 MPL-2.0 Unicode-DFS-2016"
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="net-libs/nodejs"
BDEPEND="
	dev-util/esbuild
	test? ( net-libs/nodejs )
"

QA_FLAGS_IGNORED="usr/lib/${PN}/${PV}/rollup.native.node"

src_configure() {
	# mimalloc 1.7.9 (via mimalloc-rust-sys) uses ATOMIC_VAR_INIT, which C23 removed.
	append-cflags -std=gnu17
	cargo_src_configure
}

src_compile() {
	# The parser: like upstream's "napi build --release" for bindings_napi, minus
	# the @napi-rs/cli wrapper (which only copies the library to *.node).
	cargo_src_compile --locked -p bindings_napi

	# The CLI: what upstream's rollup.config.ts makes dist/bin/rollup from, as one
	# file. Its build-time imports: package.json (JSON) and cli/help.md (text);
	# DEBUG is magic-string's build-time constant; fsevents is macOS-only. The
	# parser loader is ours, loading the addon next to the CLI.
	local esbuild
	esbuild=$(best_version -b dev-util/esbuild) || die "dev-util/esbuild not found"
	esbuild="${BROOT}/usr/bin/esbuild-$(ver_cut 1-3 "${esbuild#dev-util/esbuild-}")"
	cd "${WORKDIR}/rollup-${PV}" || die
	cp "${FILESDIR}/rollup-native-loader.js" native.js || die
	echo 'throw new Error("rollup --watch is not supported by this build");' \
		> "${T}/chokidar.js" || die
	local args=(
		cli/cli.ts --bundle --platform=node --format=cjs --target=node18
		--outfile="${WORKDIR}/rollup" --log-level=warning
		--supported:dynamic-import=true --define:DEBUG=false
		--loader:.md=text --external:fsevents --external:./rollup.native.node
		--alias:package.json=./package.json --alias:help.md=./cli/help.md
		--alias:chokidar="${T}/chokidar.js"
	)
	local _dep dep_name dep_ver dep_repo dep_tag dep_entry dep_distfile dep_dir
	for _dep in "${ROLLUP_JS_DEPS[@]}"; do
		_rollup_js_dep "${_dep}"
		[[ -f ${WORKDIR}/${dep_dir}/${dep_entry} ]] || die "${dep_name}: ${dep_entry} not found"
		args+=( --alias:"${dep_name}=${WORKDIR}/${dep_dir}/${dep_entry}" )
	done
	edo "${esbuild}" "${args[@]}"
}

src_test() {
	# Upstream's tests are rollup's JavaScript test suite; check that the CLI
	# bundles two modules with the addon.
	cp "$(cargo_target_dir)"/libbindings_napi.so "${WORKDIR}"/rollup.native.node || die
	mkdir "${T}/smoke" || die
	cd "${T}/smoke" || die
	echo 'import { b } from "./b.js"; export const a = b + 1;' > a.js || die
	echo 'export const b = 41;' > b.js || die
	node "${WORKDIR}"/rollup a.js --format esm --file out.js || die "rollup failed"
	grep -q '^const b = 41;' out.js || die "unexpected rollup output: $(<out.js)"
}

src_install() {
	exeinto "/usr/lib/${PN}/${PV}"
	doexe "${WORKDIR}"/rollup
	newexe "$(cargo_target_dir)"/libbindings_napi.so rollup.native.node
	dodoc ../README.md
}
