# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Rollup's JavaScript parser (SWC-based, Rust) as a native Node.js addon,
# built from source. Chromium bundles WebUI resources and chromium-bidi with the
# npm package @rollup/wasm-node, whose parser is a prebuilt WebAssembly module;
# the Chromium ebuild deletes that and loads this addon instead. The addon is
# rollup's own napi binding (rust/bindings_napi, what the regular "rollup" npm
# package ships as @rollup/rollup-<platform>), and exports the same functions
# as the WebAssembly one: parse, parseAsync and xxhashBase{16,36,64Url}.
#
# The parser's binary AST format belongs to one rollup release, so this is
# slotted by version and consumers pin it exactly.

CRATES="
	ahash@0.8.12
	aho-corasick@1.1.5
	allocator-api2@0.2.21
	anyhow@1.0.104
	ar_archive_writer@0.5.3
	arrayvec@0.7.8
	ascii@1.1.0
	ast_node@7.0.0
	autocfg@1.5.1
	base-encode@0.3.1
	base64@0.22.1
	base64-simd@0.8.0
	better_scoped_tls@1.0.1
	bitflags@2.13.1
	bitvec@1.1.1
	bstr@1.13.1
	bumpalo@3.20.3
	bytes@1.12.1
	bytes-str@0.2.8
	castaway@0.2.4
	cc@1.4.4
	cfg-if@1.0.4
	cmake@0.1.58
	compact_str@0.7.1
	console_error_panic_hook@0.1.7
	convert_case@0.11.0
	crossbeam-utils@0.8.22
	ctor@1.0.13
	dashmap@6.2.1
	data-encoding@2.11.1
	debugid@0.8.0
	displaydoc@0.2.7
	dragonbox_ecma@0.1.12
	either@1.18.0
	equivalent@1.0.2
	find-msvc-tools@0.1.11
	fixedbitset@0.5.7
	foldhash@0.2.0
	form_urlencoded@1.2.2
	from_variant@3.0.0
	funty@2.0.0
	futures@0.3.34
	futures-channel@0.3.34
	futures-core@0.3.34
	futures-executor@0.3.34
	futures-io@0.3.34
	futures-macro@0.3.34
	futures-sink@0.3.34
	futures-task@0.3.34
	futures-util@0.3.34
	globset@0.4.20
	hashbrown@0.14.5
	hashbrown@0.16.1
	hashbrown@0.17.1
	heck@0.5.0
	hermit-abi@0.5.2
	hstr@4.0.1
	icu_collections@2.3.0
	icu_locale_core@2.3.0
	icu_normalizer@2.3.0
	icu_normalizer_data@2.3.0
	icu_properties@2.3.0
	icu_properties_data@2.3.0
	icu_provider@2.3.1
	idna@1.1.0
	idna_adapter@1.2.2
	if_chain@1.0.3
	indexmap@2.14.0
	is-macro@0.3.8
	itoa@1.0.18
	js-sys@0.3.104
	libc@0.2.189
	libloading@0.9.0
	libmimalloc-sys2@0.1.61
	litemap@0.8.3
	lock_api@0.4.14
	memchr@2.8.3
	mimalloc-safe@0.1.65
	napi@3.12.2
	napi-build@2.4.1
	napi-derive@3.6.3
	napi-derive-backend@6.1.2
	napi-sys@3.3.0
	new_debug_unreachable@1.0.6
	nohash-hasher@0.2.0
	num-bigint@0.4.8
	num-integer@0.1.47
	num-traits@0.2.19
	num_cpus@1.17.0
	object@0.39.1
	once_cell@1.21.4
	outref@0.5.2
	par-core@2.0.0
	par-iter@2.0.0
	parking_lot@0.12.5
	parking_lot_core@0.9.12
	pathdiff@0.2.3
	percent-encoding@2.3.2
	petgraph@0.7.1
	phf@0.11.3
	phf_generator@0.11.3
	phf_macros@0.11.3
	phf_shared@0.11.3
	pin-project-lite@0.2.17
	potential_utf@0.1.6
	proc-macro2@1.0.107
	psm@0.1.32
	quote@1.0.47
	radium@0.7.0
	radix_fmt@1.0.0
	rand@0.8.7
	rand_core@0.6.4
	redox_syscall@0.5.18
	regex@1.13.1
	regex-automata@0.4.18
	regex-syntax@0.8.11
	regress@0.11.1
	rustc-hash@2.1.3
	rustversion@1.0.23
	ryu@1.0.23
	ryu-js@1.0.3
	scoped-tls@1.0.1
	scopeguard@1.2.0
	semver@1.0.28
	seq-macro@0.3.6
	serde@1.0.229
	serde_core@1.0.229
	serde_derive@1.0.229
	serde_json@1.0.151
	shlex@2.0.1
	siphasher@0.3.11
	siphasher@1.0.3
	slab@0.4.12
	smallvec@1.15.2
	stable_deref_trait@1.2.1
	stacker@0.1.25
	static_assertions@1.1.0
	string_enum@1.0.2
	swc_allocator@5.0.0
	swc_atoms@10.0.0
	swc_common@26.0.0
	swc_compiler_base@64.0.0
	swc_config@6.0.0
	swc_config_macro@1.0.1
	swc_ecma_ast@29.0.0
	swc_ecma_codegen@32.0.0
	swc_ecma_codegen_macros@2.0.2
	swc_ecma_hooks@1.0.0
	swc_ecma_minifier@61.0.1
	swc_ecma_parser@45.1.1
	swc_ecma_transforms_base@49.0.0
	swc_ecma_transforms_optimization@52.0.0
	swc_ecma_utils@35.0.0
	swc_ecma_visit@29.0.0
	swc_eq_ignore_macros@1.0.1
	swc_macros_common@1.0.1
	swc_sourcemap@10.0.2
	swc_visit@2.0.1
	syn@2.0.119
	syn@3.0.4
	synstructure@0.13.2
	tap@1.0.1
	tinystr@0.8.4
	tracing@0.1.44
	tracing-attributes@0.1.31
	tracing-core@0.1.36
	triomphe@0.1.16
	unicode-id-start@1.4.0
	unicode-ident@1.0.24
	unicode-segmentation@1.13.3
	unicode-width@0.2.2
	url@2.5.8
	utf8_iter@1.0.4
	uuid@1.25.0
	version_check@0.9.5
	vsimd@0.8.0
	wasm-bindgen@0.2.127
	wasm-bindgen-macro@0.2.127
	wasm-bindgen-macro-support@0.2.127
	wasm-bindgen-shared@0.2.127
	windows-link@0.2.1
	windows-sys@0.61.2
	writeable@0.6.4
	wyz@0.5.1
	xxhash-rust@0.8.18
	yoke@0.8.3
	yoke-derive@0.8.2
	zerocopy@0.8.56
	zerocopy-derive@0.8.56
	zerofrom@0.1.8
	zerofrom-derive@0.1.7
	zerotrie@0.2.5
	zerovec@0.11.8
	zerovec-derive@0.11.6
	zmij@1.0.23
"

inherit cargo

DESCRIPTION="Rollup's native JavaScript parser addon (napi), built from source"
HOMEPAGE="https://rollupjs.org/ https://github.com/rollup/rollup"
SRC_URI="
	https://github.com/rollup/rollup/archive/refs/tags/v${PV}.tar.gz -> rollup-${PV}.gh.tar.gz
	${CARGO_CRATE_URIS}
"
S="${WORKDIR}/rollup-${PV}/rust"

LICENSE="MIT"
# Dependent crate licenses
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD Boost-1.0 ISC Unicode-3.0 ZLIB"
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"
IUSE="test"
RESTRICT="!test? ( test )"

BDEPEND="test? ( net-libs/nodejs )"

QA_FLAGS_IGNORED="usr/lib/${PN}/${PV}/rollup.native.node"

src_compile() {
	# Like upstream's "napi build --release" for bindings_napi, minus the
	# @napi-rs/cli wrapper (which only copies the library to *.node).
	cargo_src_compile --locked -p bindings_napi
}

src_test() {
	# Upstream's tests are rollup's JavaScript test suite; check that the
	# addon loads in Node.js and parses.
	cp "$(cargo_target_dir)"/libbindings_napi.so "${T}"/rollup.native.node || die
	node -e '
		const b = require(process.argv[1]);
		const ast = b.parse("export const a = 1;", false, false);
		if (!(ast instanceof Uint8Array) || ast.length < 16) process.exit(1);
		if (!/^[0-9a-f]+$/.test(b.xxhashBase16(new Uint8Array([1, 2, 3])))) process.exit(1);
	' "${T}"/rollup.native.node || die "addon smoke test failed"
}

src_install() {
	exeinto "/usr/lib/${PN}/${PV}"
	newexe "$(cargo_target_dir)"/libbindings_napi.so rollup.native.node
	dodoc ../README.md
}
