# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Some of the Rust crates Chromium vendors (third_party/rust/chromium_crates_io/
# vendor/) contain generated code and data, as crates.io publishes them. This
# regenerates those files with their upstream generators, from their real inputs,
# and installs them at the paths of the files they replace
# (/usr/lib/chromium-rust-crates/SLOT/vendor/<crate>-<epoch>/...). The Chromium
# ebuild copies them over the originals, after checking the crates' versions
# (VERSIONS). Built once per Chromium major version.
#
# What, by which generator (sources at the commits the crates were published
# from, .cargo_vcs_info.json):
# - syn 2 and 3: src/gen/ (syn-internal-codegen)
# - regex-syntax: src/unicode_tables/ (ucd-generate 0.3.1, as regex-cli runs it,
#   from Unicode 16.0.0's UCD)
# - unicode-ident: src/tables.rs (its generate tool, Unicode 17.0.0)
# - unicode-width: src/tables.rs (scripts/unicode.py, Unicode 17.0.0)
# - rustfft: the SIMD prime-size butterflies (tools/gen_simd_butterflies)
# - read-fonts, write-fonts, skrifa: fontations' codegen, from its table
#   definitions, and its Python table scripts (all from one fontations commit,
#   whose generators and inputs give all three crates' files)
# - the ICU4X data crates (calendar, locale, normalizer, properties): ICU4X's
#   bakeddata, from CLDR's JSON (cldr-core, cldr-misc-full) and ICU's export data;
#   icu_capi's generated FFI code: ICU4X's codegen
# - timezone_provider: temporal_rs' bakeddata, from IANA's tzdata (2025c)
# - zoneinfo64's zoneinfo64.res: ICU's genrb, from ICU's zoneinfo64.txt (2025c)
SYN2_COMMIT="3295f9e9841785ac88a5e558c884854d5fb7d67f" # 2.0.119
SYN3_COMMIT="e0ad92d68b588c964e82bb74c3bd3e1e99f97ceb" # 3.0.5
UNICODE_IDENT_COMMIT="5b54a632702b5744a1c40ea01c127c0ac0498172" # 1.0.24
UNICODE_WIDTH_COMMIT="9d98411769fe13c7c18cab0b3fbbab29ba8350ea" # 0.2.2
RUSTFFT_COMMIT="4758ab0dd6f256c50ac8987c75c9cb96152dc2ca" # 6.4.1
FONTATIONS_COMMIT="a2be65244af08f403bf580f37d246146b58a473f" # read-fonts 0.43.3
ICU4X_COMMIT="c9fac4e625ccb2c6a7aa35079fff9709db4385ac" # 2.2.0
TEMPORAL_COMMIT="6a5d18375acd62ba778726df68cdc9dd3d09f285" # timezone_provider 0.2.6
ICU_DATA_COMMIT="6e2dfbcdd5da2148f13e78e15c22fec5637ee4a2" # icu-data: tzdata 2025c
CLDR_VER="48.2.0"
ICUEXPORT_VER="78.1rc"
TZDATA_VER="2025c"

# The crates the generators are built with (from their Cargo.lock files: the
# tools' own, or files/*.Cargo.lock for those that don't commit one), minus
# CARGO_STUB_CRATES.
CRATES="
	addr2line@0.25.1
	adler2@2.0.1
	aho-corasick@1.1.5
	allocator-api2@0.2.21
	anstream@1.0.0
	anstyle@1.0.14
	anstyle-parse@1.0.0
	anstyle-query@1.1.5
	anyhow@1.0.104
	askama@0.15.6
	askama_derive@0.15.6
	askama_macros@0.15.6
	askama_parser@0.15.6
	autocfg@1.5.0
	backtrace@0.3.76
	backtrace-ext@0.2.1
	basic-toml@0.1.10
	bitflags@1.3.2
	bitflags@2.13.2
	cfg-if@1.0.4
	cfg-if@1.0.5
	clap@2.34.0
	cobs@0.3.0
	color-backtrace@0.7.4
	colorchoice@1.0.5
	colored@3.1.1
	core_maths@0.1.1
	crc32fast@1.5.0
	crossbeam-deque@0.8.6
	crossbeam-deque@0.8.8
	crossbeam-epoch@0.9.18
	crossbeam-epoch@0.9.21
	crossbeam-utils@0.8.21
	crossbeam-utils@0.8.23
	databake@0.2.1
	databake-derive@0.2.0
	deranged@0.5.5
	displaydoc@0.2.5
	either@1.15.0
	either@1.19.0
	elsa@1.11.2
	env_filter@2.0.0
	env_logger@0.11.11
	equivalent@1.0.2
	equivalent@1.0.3
	erased-serde@0.4.10
	fastrand@2.5.0
	filetime@0.2.27
	flate2@1.1.9
	foldhash@0.2.0
	fst@0.4.7
	getrandom@0.4.3
	gimli@0.32.3
	handlebars@5.1.0
	hashbrown@0.16.0
	hashbrown@0.16.1
	hashbrown@0.17.1
	heck@0.4.1
	heck@0.5.0
	home@0.5.11
	indexmap@2.11.4
	indexmap@2.14.0
	indexmap@2.14.2
	indoc@2.0.8
	inflections@1.1.1
	is-terminal@0.4.17
	is_ci@1.2.0
	is_terminal_polyfill@1.70.2
	itertools@0.14.0
	itoa@1.0.10
	itoa@1.0.15
	itoa@1.0.18
	jiff@0.2.38
	jiff-core@0.1.1
	libc@0.2.183
	libc@0.2.190
	libm@0.2.16
	linux-raw-sys@0.12.1
	litemap@0.8.0
	log@0.4.21
	log@0.4.29
	log@0.4.34
	matrixmultiply@0.3.10
	memchr@2.7.1
	memchr@2.8.0
	memchr@2.8.3
	miette@5.10.0
	miette-derive@5.10.0
	miniz_oxide@0.8.9
	ndarray@0.16.1
	num-bigint@0.4.6
	num-complex@0.4.6
	num-conv@0.1.0
	num-integer@0.1.46
	num-rational@0.4.2
	num-traits@0.2.19
	num_threads@0.1.7
	object@0.37.3
	once_cell@1.19.0
	once_cell@1.21.4
	ordered-float@2.10.1
	owo-colors@3.5.0
	parse-zoneinfo@0.5.0
	percent-encoding@2.3.2
	pest@2.7.8
	pest_derive@2.7.8
	pest_generator@2.7.8
	pest_meta@2.7.8
	postcard@1.1.3
	powerfmt@0.2.0
	prettyplease@0.2.37
	prettyplease@0.3.0
	proc-macro2@1.0.106
	proc-macro2@1.0.107
	proc-macro2@1.0.79
	quote@1.0.35
	quote@1.0.45
	quote@1.0.47
	rawpointer@0.2.1
	rayon@1.10.0
	rayon@1.12.0
	rayon-core@1.12.1
	rayon-core@1.13.0
	regex@1.13.1
	regex-automata@0.4.14
	regex-automata@0.4.18
	regex-lite@0.1.0
	regex-syntax@0.8.10
	regex-syntax@0.8.11
	rustc-demangle@0.1.28
	rustc-hash@2.1.1
	rustc-hash@2.1.2
	rustfmt-wrapper@0.2.1
	rustix@1.1.5
	ryu@1.0.17
	same-file@1.0.6
	semver@1.0.28
	serde@1.0.197
	serde@1.0.228
	serde@1.0.229
	serde-aux@4.7.0
	serde-value@0.7.0
	serde_core@1.0.228
	serde_core@1.0.229
	serde_derive@1.0.197
	serde_derive@1.0.228
	serde_derive@1.0.229
	serde_json@1.0.114
	serde_json@1.0.149
	serde_json@1.0.150
	serde_json@1.0.154
	serde_spanned@0.6.9
	serde_spanned@1.1.2
	simd-adler32@0.3.8
	simple_logger@5.1.0
	smallvec@1.15.1
	smawk@0.3.3
	stable_deref_trait@1.2.0
	stable_deref_trait@1.2.1
	strsim@0.8.0
	supports-color@2.1.0
	supports-hyperlinks@2.1.0
	supports-unicode@2.1.0
	syn@2.0.117
	syn@2.0.118
	syn@2.0.119
	syn@2.0.53
	syn@3.0.9
	synstructure@0.13.2
	tar@0.4.45
	tempfile@3.27.0
	termcolor@1.4.1
	terminal_size@0.1.17
	textwrap@0.11.0
	textwrap@0.15.2
	thiserror@1.0.58
	thiserror@1.0.69
	thiserror@2.0.18
	thiserror-impl@1.0.58
	thiserror-impl@1.0.69
	thiserror-impl@2.0.18
	time@0.3.45
	time-core@0.1.7
	time-macros@0.2.25
	tinystr@0.8.3
	toml@0.8.23
	toml@1.1.8+spec-1.1.0
	toml_datetime@0.6.11
	toml_datetime@1.1.2+spec-1.1.0
	toml_edit@0.22.27
	toml_parser@1.1.5+spec-1.1.0
	toml_write@0.1.2
	toolchain_find@0.4.0
	twox-hash@2.1.2
	typed-arena@2.0.2
	typeid@1.0.3
	ucd-generate@0.3.1
	ucd-parse@0.1.13
	ucd-trie@0.1.6
	ucd-trie@0.1.7
	ucd-util@0.2.2
	unicode-ident@1.0.12
	unicode-ident@1.0.18
	unicode-ident@1.0.24
	unicode-ident@1.0.27
	unicode-linebreak@0.1.5
	unicode-width@0.1.10
	unicode-width@0.1.14
	utf16_iter@1.0.5
	utf8_iter@1.0.4
	utf8parse@0.2.2
	walkdir@2.5.0
	winnow@0.7.15
	winnow@1.0.0
	winnow@1.0.4
	write16@1.0.0
	xflags@0.3.2
	xflags-macros@0.3.2
	yoke@0.8.2
	yoke-derive@0.8.2
	zerofrom@0.1.6
	zerofrom-derive@0.1.6
	zerotrie@0.2.4
	zerovec@0.11.6
	zerovec-derive@0.11.3
	zip@2.4.2
	zmij@1.0.21
	zmij@1.0.23
	zopfli@0.8.0
"

# Locked, but never built here (other platforms, unused features, tests).
CARGO_STUB_CRATES="
	addr2line@0.24.2
	ahash@0.7.8
	aho-corasick@1.1.4
	android_system_properties@0.1.5
	anes@0.1.6
	anstream@0.6.21
	anstyle-parse@0.2.7
	anstyle-wincon@3.0.11
	arbitrary@1.4.2
	arraystring@0.3.0
	arrayvec@0.7.6
	atoi@2.0.0
	autocfg@1.4.0
	backtrace@0.3.74
	base64@0.22.1
	bincode@1.3.3
	bitflags@2.11.0
	bitvec@1.0.1
	block-buffer@0.10.4
	bumpalo@3.17.0
	bumpalo@3.20.2
	bytecheck@0.6.12
	bytecheck_derive@0.6.12
	bytemuck@1.25.2
	bytemuck_derive@1.12.1
	byteorder@1.5.0
	bytes@1.11.1
	calendrical_calculations@0.2.4
	cast@0.3.0
	cc@1.2.24
	cc@1.2.57
	cfg-expr@0.20.7
	cfg-if@1.0.0
	chrono@0.4.44
	chrono-tz@0.10.4
	ciborium@0.2.2
	ciborium-io@0.2.2
	ciborium-ll@0.2.2
	clap@4.4.18
	clap_builder@4.4.18
	clap_derive@4.4.7
	clap_lex@0.6.0
	combine@4.6.7
	console@0.15.11
	core-foundation@0.10.1
	core-foundation-sys@0.8.7
	cpufeatures@0.2.12
	criterion@0.5.1
	criterion-plot@0.5.0
	crunchy@0.2.4
	crypto-common@0.1.6
	defmt@1.2.0
	defmt-macros@1.2.0
	defmt-parser@1.1.0
	derive_arbitrary@1.4.2
	detone@1.0.1
	dhat@0.3.3
	digest@0.10.7
	dlmalloc@0.2.13
	dyn-clone@1.0.20
	embedded-io@0.4.0
	embedded-io@0.6.1
	encode_unicode@1.0.0
	errno@0.3.14
	fastrand@2.3.0
	find-msvc-tools@0.1.9
	foldhash@0.1.5
	funty@2.0.0
	futures-channel@0.3.32
	futures-core@0.3.32
	futures-executor@0.3.32
	futures-io@0.3.32
	futures-macro@0.3.32
	futures-task@0.3.32
	futures-util@0.3.32
	generic-array@0.14.7
	getrandom@0.2.17
	getrandom@0.3.4
	gimli@0.31.1
	gio@0.21.5
	gio-sys@0.21.5
	glib@0.21.5
	glib-macros@0.21.5
	glib-sys@0.21.5
	gobject-sys@0.21.5
	half@2.4.1
	harfbuzz-traits@0.6.0
	hashbrown@0.12.3
	hashbrown@0.15.5
	hermit-abi@0.5.2
	hermit-abi@0.5.3
	http@1.4.0
	httparse@1.10.1
	iai@0.1.1
	iana-time-zone@0.1.65
	iana-time-zone-haiku@0.1.2
	icu_calendar@2.2.1
	icu_calendar_data@2.2.0
	icu_collections@2.2.0
	icu_locale@2.2.0
	icu_locale_core@2.2.0
	icu_locale_data@2.2.0
	icu_provider@2.2.0
	icu_time@2.2.0
	icu_time_data@2.2.0
	insta@1.46.3
	itertools@0.10.5
	ixdtf@0.6.5
	jiff@0.2.23
	jiff-static@0.2.23
	jiff-static@0.2.38
	jiff-tzdb@0.1.4
	jiff-tzdb@0.1.6
	js-sys@0.3.77
	js-sys@0.3.91
	lazy_static@1.5.0
	leb128fmt@0.1.0
	libc@0.2.153
	libc@0.2.172
	libm@0.2.15
	libredox@0.1.15
	lock_api@0.4.14
	log@0.4.32
	mintex@0.1.4
	object@0.36.7
	once_cell@1.18.0
	once_cell@1.21.3
	once_cell_polyfill@1.70.2
	oorandom@11.1.5
	parking_lot@0.12.5
	parking_lot_core@0.9.12
	paste@1.0.15
	phf@0.12.1
	phf_shared@0.12.1
	pin-project-lite@0.2.17
	pkg-config@0.3.32
	plain@0.2.3
	plotters@0.3.7
	plotters-backend@0.3.7
	plotters-svg@0.3.7
	portable-atomic@1.13.1
	portable-atomic@1.15.0
	portable-atomic-util@0.2.6
	portable-atomic-util@0.2.8
	potential_utf@0.1.3
	ppv-lite86@0.2.21
	proc-macro-crate@3.4.0
	ptr_meta@0.1.4
	ptr_meta_derive@0.1.4
	r-efi@5.3.0
	r-efi@6.0.0
	radium@0.7.0
	rand@0.9.2
	rand_chacha@0.9.0
	rand_core@0.9.5
	rand_distr@0.5.1
	rand_pcg@0.9.0
	redox_syscall@0.5.18
	redox_syscall@0.7.3
	ref-cast@1.0.25
	ref-cast-impl@1.0.25
	regex@1.12.3
	rend@0.4.2
	resb@0.1.2
	ring@0.17.14
	rkyv@0.7.46
	rkyv_derive@0.7.46
	rmp@0.8.14
	rmp-serde@1.3.0
	rustc-demangle@0.1.27
	rustc-hash@1.1.0
	rustix@1.1.4
	rustls@0.23.37
	rustls-pki-types@1.14.0
	rustls-webpki@0.103.10
	rustversion@1.0.21
	rustversion@1.0.22
	rustversion@1.0.23
	ryu@1.0.23
	schemars@1.2.1
	scopeguard@1.2.0
	seahash@4.1.0
	semver@1.0.27
	serde-json-core@0.6.0
	sha2@0.10.8
	shlex@1.3.0
	simdutf8@0.1.5
	similar@2.7.0
	siphasher@1.0.2
	slab@0.4.12
	spin@0.9.8
	string-interner@0.19.0
	strsim@0.10.0
	subtle@2.6.1
	syn@1.0.109
	system-deps@7.0.4
	tap@1.0.1
	target-lexicon@0.13.3
	thiserror@2.0.21
	thiserror-impl@2.0.21
	thousands@0.2.0
	tinytemplate@1.2.1
	tinyvec@1.11.0
	tinyvec_macros@0.1.1
	toml_datetime@0.7.1
	toml_edit@0.23.5
	toml_parser@1.0.2
	typenum@1.17.0
	typenum@1.19.0
	tzif@0.4.0
	unicode-bidi@0.3.18
	unicode-width@0.2.2
	untrusted@0.9.0
	ureq@3.2.1
	ureq-proto@0.5.3
	utf8-zero@0.8.1
	uuid@1.20.0
	version-compare@0.2.1
	version_check@0.9.4
	version_check@0.9.5
	wasi@0.11.1+wasi-snapshot-preview1
	wasip2@1.0.1+wasi-0.2.4
	wasm-bindgen@0.2.100
	wasm-bindgen@0.2.114
	wasm-bindgen-backend@0.2.100
	wasm-bindgen-macro@0.2.100
	wasm-bindgen-macro@0.2.114
	wasm-bindgen-macro-support@0.2.100
	wasm-bindgen-macro-support@0.2.114
	wasm-bindgen-shared@0.2.100
	wasm-bindgen-shared@0.2.114
	wasm-encoder@0.244.0
	wasmi@1.0.9
	wasmi_collections@1.0.9
	wasmi_core@1.0.9
	wasmi_ir@1.0.9
	wasmparser@0.228.0
	wasmparser@0.244.0
	wast@244.0.0
	wat@1.244.0
	web-sys@0.3.91
	web-time@1.1.0
	webpki-roots@1.0.6
	winapi@0.3.9
	winapi-i686-pc-windows-gnu@0.4.0
	winapi-util@0.1.11
	winapi-x86_64-pc-windows-gnu@0.4.0
	windows@0.62.2
	windows-collections@0.3.2
	windows-core@0.58.0
	windows-core@0.61.2
	windows-core@0.62.2
	windows-future@0.3.2
	windows-implement@0.58.0
	windows-implement@0.60.0
	windows-implement@0.60.2
	windows-interface@0.58.0
	windows-interface@0.59.1
	windows-interface@0.59.3
	windows-link@0.1.1
	windows-link@0.2.1
	windows-numerics@0.3.1
	windows-result@0.2.0
	windows-result@0.3.4
	windows-result@0.4.1
	windows-strings@0.1.0
	windows-strings@0.4.2
	windows-strings@0.5.1
	windows-sys@0.52.0
	windows-sys@0.59.0
	windows-sys@0.61.2
	windows-targets@0.52.6
	windows-threading@0.2.1
	windows_aarch64_gnullvm@0.52.6
	windows_aarch64_msvc@0.52.6
	windows_i686_gnu@0.52.6
	windows_i686_gnullvm@0.52.6
	windows_i686_msvc@0.52.6
	windows_x86_64_gnu@0.52.6
	windows_x86_64_gnullvm@0.52.6
	windows_x86_64_msvc@0.52.6
	wit-bindgen@0.46.0
	writeable@0.6.2
	wyz@0.5.1
	zerocopy@0.8.47
	zerocopy-derive@0.8.47
	zeroize@1.8.2
	zoneinfo64@0.3.0
"

# Newest rust-version among the crates.
RUST_MIN_VER="1.88.0"
RUST_REQ_USE="rustfmt"
PYTHON_COMPAT=( python3_{12..15} )

inherit cargo cargo-stubs

DESCRIPTION="Regenerated generated files of the Rust crates Chromium vendors"
HOMEPAGE="https://chromium.googlesource.com/chromium/src/+/main/third_party/rust/"
_gh() { # repository commit [name]
	echo "https://github.com/${1}/archive/${2}.tar.gz -> ${3:-${1#*/}}-${2}.gh.tar.gz"
}
SRC_URI="
	$(_gh dtolnay/syn ${SYN2_COMMIT})
	$(_gh dtolnay/syn ${SYN3_COMMIT})
	$(_gh dtolnay/unicode-ident ${UNICODE_IDENT_COMMIT})
	$(_gh unicode-rs/unicode-width ${UNICODE_WIDTH_COMMIT})
	$(_gh ejmahler/RustFFT ${RUSTFFT_COMMIT} rustfft)
	$(_gh googlefonts/fontations ${FONTATIONS_COMMIT})
	$(_gh unicode-org/icu4x ${ICU4X_COMMIT})
	$(_gh boa-dev/temporal ${TEMPORAL_COMMIT} temporal_rs)
	https://unicode.org/Public/16.0.0/ucd/UCD.zip -> unicode-data-16.0.0-UCD.zip
	https://unicode.org/Public/zipped/17.0.0/UCD.zip -> unicode-data-17.0.0-UCD.zip
	https://registry.npmjs.org/cldr-core/-/cldr-core-${CLDR_VER}.tgz
	https://registry.npmjs.org/cldr-misc-full/-/cldr-misc-full-${CLDR_VER}.tgz
	https://github.com/unicode-org/icu/releases/download/release-${ICUEXPORT_VER}/icu4x-icuexportdata-${ICUEXPORT_VER}.zip
	https://data.iana.org/time-zones/releases/tzdata${TZDATA_VER}.tar.gz
	https://raw.githubusercontent.com/unicode-org/icu-data/${ICU_DATA_COMMIT}/tzdata/icunew/${TZDATA_VER}/44/zoneinfo64.txt
		-> icu-data-zoneinfo64-${TZDATA_VER}.txt
	${CARGO_CRATE_URIS}
"
unset -f _gh
S="${WORKDIR}"

# What is installed: the generated files of the crates above.
LICENSE="Apache-2.0 MIT Unicode-3.0 public-domain"
SLOT="$(ver_cut 1)"
KEYWORDS="~amd64 ~arm64"
RESTRICT="test"

# genrb, and ICU4C's code point trie builder for ICU4X's property tries.
BDEPEND="
	app-arch/unzip
	dev-libs/icu
"

src_unpack() {
	local a
	for a in ${A}; do
		case ${a} in
			# Unpacked where they are used (cldr-*: both unpack to package/;
			# tzdata: to the current directory).
			*.crate|*.txt|unicode-data-*|icu4x-icuexportdata-*|cldr-*|tzdata*) ;;
			*) unpack "${a}" ;;
		esac
	done
	mkdir -p "${WORKDIR}"/ucd-{16,17}.0.0 || die
	unzip -qo "${DISTDIR}/unicode-data-16.0.0-UCD.zip" -d "${WORKDIR}/ucd-16.0.0" || die
	unzip -qo "${DISTDIR}/unicode-data-17.0.0-UCD.zip" -d "${WORKDIR}/ucd-17.0.0" || die

	# Lockfiles for the tools that don't commit one.
	cp "${FILESDIR}/${PN}-156-fontations.Cargo.lock" "fontations-${FONTATIONS_COMMIT}/Cargo.lock" || die
	cp "${FILESDIR}/${PN}-156-unicode-ident.Cargo.lock" "unicode-ident-${UNICODE_IDENT_COMMIT}/generate/Cargo.lock" || die
	cp "${FILESDIR}/${PN}-156-syn-2-codegen.Cargo.lock" "syn-${SYN2_COMMIT}/codegen/Cargo.lock" || die
	cp "${FILESDIR}/${PN}-156-syn-3-codegen.Cargo.lock" "syn-${SYN3_COMMIT}/codegen/Cargo.lock" || die

	# Only some of ICU4X's and temporal_rs' workspace members are built (see the
	# patches; temporal_rs' root package is a member too): drop what the others
	# need from their lockfiles.
	"${EPYTHON}" "${FILESDIR}/${PN}-prune-lock.py" "icu4x-${ICU4X_COMMIT}/Cargo.lock" bakeddata codegen || die
	"${EPYTHON}" "${FILESDIR}/${PN}-prune-lock.py" "temporal-${TEMPORAL_COMMIT}/Cargo.lock" bakeddata temporal_rs || die

	cargo_crate_unpack
	cargo_gen_config
	local CARGO_STUB_LOCKFILE="
		${WORKDIR}/fontations-${FONTATIONS_COMMIT}/Cargo.lock
		${WORKDIR}/unicode-ident-${UNICODE_IDENT_COMMIT}/generate/Cargo.lock
		${WORKDIR}/syn-${SYN2_COMMIT}/codegen/Cargo.lock
		${WORKDIR}/syn-${SYN3_COMMIT}/codegen/Cargo.lock
		${WORKDIR}/icu4x-${ICU4X_COMMIT}/Cargo.lock
		${WORKDIR}/temporal-${TEMPORAL_COMMIT}/Cargo.lock
		${WORKDIR}/RustFFT-${RUSTFFT_COMMIT}/tools/gen_simd_butterflies/Cargo.lock
		${ECARGO_VENDOR}/ucd-generate-0.3.1/Cargo.lock
	"
	cargo_stub_crates
}

src_prepare() {
	local p d
	for p in fontations icu4x temporal unicode-ident; do
		case ${p} in
			fontations) d=${WORKDIR}/fontations-${FONTATIONS_COMMIT} ;;
			icu4x) d=${WORKDIR}/icu4x-${ICU4X_COMMIT} ;;
			temporal) d=${WORKDIR}/temporal-${TEMPORAL_COMMIT} ;;
			unicode-ident) d=${WORKDIR}/unicode-ident-${UNICODE_IDENT_COMMIT} ;;
		esac
		pushd "${d}" >/dev/null || die
		eapply "${FILESDIR}/${PN}-156-${p}.patch"
		popd >/dev/null || die
	done
	eapply_user
}

# Runs cargo in the given directory, with its own target directory.
_cargo_in() {
	local dir=${1}
	shift
	pushd "${dir}" >/dev/null || die
	local -x CARGO_TARGET_DIR="${WORKDIR}/target/${dir##*/}"
	set -- "${CARGO}" "$@"
	einfo "${@}"
	cargo_env "${@}" || die "cargo failed in ${dir}"
	popd >/dev/null || die
}

# Prints the path of a binary built by _cargo_in: _cargo_bin <directory name> <binary>
_cargo_bin() {
	local f
	for f in "${WORKDIR}/target/${1}"/{$(rust_abi)/,}release/"${2}"; do
		[[ -x ${f} ]] && { echo "${f}"; return; }
	done
	die "${2} was not built"
}

src_compile() {
	local -x PYTHONDONTWRITEBYTECODE=1 RUSTFMT="$(type -P rustfmt)"
	[[ -x ${RUSTFMT} ]] || die "rustfmt not found"
	local out="${WORKDIR}/out" d f
	mkdir -p "${out}" || die

	einfo "syn: src/gen/"
	for d in "syn-${SYN2_COMMIT}" "syn-${SYN3_COMMIT}"; do
		_cargo_in "${WORKDIR}/${d}/codegen" run --release --locked
	done

	einfo "regex-syntax: Unicode tables"
	_cargo_in "${ECARGO_VENDOR}/ucd-generate-0.3.1" build --release --locked
	local ucdgen
	ucdgen=$(_cargo_bin ucd-generate-0.3.1 ucd-generate) || die
	local tables="${out}/regex-syntax/src/unicode_tables"
	mkdir -p "${tables}" || die
	# regex's rustfmt.toml, for rustfmt to find above the tables.
	printf 'max_width = 79\nuse_small_heuristics = "max"\n' > "${out}/regex-syntax/rustfmt.toml" || die
	# regex-cli/cmd/generate/unicode.rs; the UCD directory's name ends up in the
	# files' headers.
	pushd "${WORKDIR}" >/dev/null || die
	local -a gen=(
		"age.rs age --chars"
		"case_folding_simple.rs case-folding-simple --chars --all-pairs"
		"general_category.rs general-category --chars --exclude surrogate"
		"grapheme_cluster_break.rs grapheme-cluster-break --chars"
		"property_bool.rs property-bool --chars"
		"property_names.rs property-names"
		"property_values.rs property-values --include gc,script,scx,age,gcb,wb,sb"
		"script.rs script --chars"
		"script_extension.rs script-extension --chars"
		"sentence_break.rs sentence-break --chars"
		"word_break.rs word-break --chars"
		"perl_word.rs perl-word --chars"
		"perl_decimal.rs general-category --chars --include decimalnumber"
		"perl_space.rs property-bool --chars --include whitespace"
	)
	local g file cmd args
	for g in "${gen[@]}"; do
		read -r file cmd args <<<"${g}"
		# shellcheck disable=SC2086
		"${ucdgen}" ${cmd} ucd-16.0.0 ${args} > "${tables}/${file}" || die "ucd-generate ${cmd} failed"
		"${RUSTFMT}" "${tables}/${file}" || die
	done
	popd >/dev/null || die

	einfo "unicode-ident: src/tables.rs"
	d="${WORKDIR}/unicode-ident-${UNICODE_IDENT_COMMIT}"
	ln -s "${WORKDIR}/ucd-17.0.0" "${d}/UCD" || die
	_cargo_in "${d}" run --release --locked --manifest-path generate/Cargo.toml

	einfo "unicode-width: src/tables.rs"
	d="${WORKDIR}/unicode-width-${UNICODE_WIDTH_COMMIT}/scripts"
	# The script reads the UCD files (by their base names) from its directory, and emoji-test.txt
	# from ../tests (in the repository), and downloads any that are missing: make that an error.
	for f in "${WORKDIR}"/ucd-17.0.0/{,auxiliary/,extracted/}*.txt \
		"${WORKDIR}"/ucd-17.0.0/emoji/emoji-{data,variation-sequences}.txt; do
		ln -s "${f}" "${d}/" || die
	done
	sed -i 's|^\( *\)urllib.request.urlretrieve($|\1sys.exit(f"{localname} is missing")\n&|' "${d}"/unicode.py || die
	grep -q 'sys.exit(f"{localname} is missing")' "${d}"/unicode.py ||
		die "Failed to disable unicode-width's downloads"
	pushd "${d}" >/dev/null || die
	"${EPYTHON}" unicode.py || die "unicode-width's unicode.py failed"
	popd >/dev/null || die

	einfo "rustfft: SIMD butterflies"
	d="${WORKDIR}/RustFFT-${RUSTFFT_COMMIT}"
	_cargo_in "${d}/tools/gen_simd_butterflies" build --release --locked
	local arch
	for arch in sse neon wasm_simd; do
		mkdir -p "${out}/rustfft/src/${arch}" || die
		"$(_cargo_bin gen_simd_butterflies gen_simd_butterflies)" ${arch} 7 11 13 17 19 23 29 31 > "${out}/rustfft/src/${arch}/${arch}_prime_butterflies.rs" ||
			die "gen_simd_butterflies ${arch} failed"
	done

	einfo "fontations: read-fonts, write-fonts, skrifa"
	d="${WORKDIR}/fontations-${FONTATIONS_COMMIT}"
	_cargo_in "${d}" run --release --locked --bin=codegen -- resources/codegen_plan.toml
	pushd "${d}/read-fonts/scripts" >/dev/null || die
	"${EPYTHON}" gen_agl.py || die
	"${EPYTHON}" gen_tables.py || die
	popd >/dev/null || die
	pushd "${d}/skrifa/scripts" >/dev/null || die
	"${EPYTHON}" gen_autohint_styles.py || die
	popd >/dev/null || die

	einfo "ICU4X: baked data and icu_capi"
	d="${WORKDIR}/icu4x-${ICU4X_COMMIT}"
	local pkg
	for pkg in cldr-core cldr-misc-full; do
		mkdir -p "${WORKDIR}/cldr/${pkg}" || die
		tar -xzf "${DISTDIR}/${pkg}-${CLDR_VER}.tgz" -C "${WORKDIR}/cldr/${pkg}" --strip-components=1 || die
	done
	# The data crates' manifests stay (the workspace needs them); their data is
	# what bakeddata writes.
	for f in calendar locale normalizer properties; do
		rm -r "${d}/provider/data/${f}/data" || die
	done
	local -x ICU4X_CLDR_DIR="${WORKDIR}/cldr"
	local -x ICU4X_ICUEXPORT_DIR="${DISTDIR}/icu4x-icuexportdata-${ICUEXPORT_VER}.zip"
	local -x ICU4C_LIB_PATH="${ESYSROOT}/usr/$(get_libdir)"
	_cargo_in "${d}" run --release -p bakeddata -- calendar locale normalizer properties
	_cargo_in "${d}" run --release -p codegen

	einfo "timezone_provider: tzdata ${TZDATA_VER}"
	d="${WORKDIR}/tzdata"
	mkdir -p "${d}" || die
	tar -xzf "${DISTDIR}/tzdata${TZDATA_VER}.tar.gz" -C "${d}" || die
	emake -C "${d}" rearguard.zi
	local -x TZDATA_DIR="${d}"
	_cargo_in "${WORKDIR}/temporal-${TEMPORAL_COMMIT}" run --release -p bakeddata

	einfo "zoneinfo64: zoneinfo64.res"
	mkdir -p "${out}/zoneinfo64" || die
	cp "${DISTDIR}/icu-data-zoneinfo64-${TZDATA_VER}.txt" "${WORKDIR}/zoneinfo64.txt" || die
	genrb -q -d "${out}/zoneinfo64" "${WORKDIR}/zoneinfo64.txt" || die "genrb failed"
}

src_install() {
	local root="/usr/lib/${PN}/${SLOT}/vendor" v="${ED}/usr/lib/${PN}/${SLOT}/VERSIONS"
	# Directories that are generated as a whole (optionally: the files matching a
	# pattern): the Chromium ebuild checks that every file in them is replaced.
	local dirs="${ED}/usr/lib/${PN}/${SLOT}/DIRS"
	# _ins <Chromium's crate directory> <crate version> <destination> <files...>
	_ins() {
		local crate=${1} version=${2} dest=${3}
		shift 3
		insinto "${root}/${crate}/${dest}"
		doins "$@"
		grep -qx "${crate} ${version}" "${v}" 2>/dev/null || echo "${crate} ${version}" >> "${v}" || die
	}
	dodir "/usr/lib/${PN}/${SLOT}"
	local w="${WORKDIR}" out="${WORKDIR}/out" c
	_ins syn-v2 2.0.119 src/gen "${w}/syn-${SYN2_COMMIT}"/src/gen/*.rs
	_ins syn-v3 3.0.5 src/gen "${w}/syn-${SYN3_COMMIT}"/src/gen/*.rs
	_ins regex-syntax-v0_8 0.8.11 src/unicode_tables "${out}"/regex-syntax/src/unicode_tables/*.rs
	_ins unicode-ident-v1 1.0.24 src "${w}/unicode-ident-${UNICODE_IDENT_COMMIT}/src/tables.rs"
	_ins unicode-width-v0_2 0.2.2 src "${w}/unicode-width-${UNICODE_WIDTH_COMMIT}/src/tables.rs"
	for c in sse neon wasm_simd; do
		_ins rustfft-v6 6.4.1 src/${c} "${out}/rustfft/src/${c}/${c}_prime_butterflies.rs"
	done
	local f="${w}/fontations-${FONTATIONS_COMMIT}"
	_ins read-fonts-v0_43 0.43.3 generated "${f}"/read-fonts/generated/*.rs
	_ins read-fonts-v0_43 0.43.3 data/generated "${f}"/read-fonts/data/generated/*.rs
	_ins write-fonts-v0_52 0.52.0 generated "${f}"/write-fonts/generated/*.rs
	_ins skrifa-v0_46 0.46.2 generated "${f}/skrifa/generated/generated_autohint_styles.rs"
	local i="${w}/icu4x-${ICU4X_COMMIT}"
	for c in calendar locale normalizer properties; do
		_ins icu_${c}_data-v2 2.2.0 data "${i}/provider/data/${c}/data"/*
	done
	_ins icu_capi-v2 2.2.0 src "${i}"/ffi/capi/src/{date_formatter,date_time_formatter,time_formatter,timezone_formatter,zoned_date_formatter,zoned_date_time_formatter,zoned_time_formatter,properties_enums,properties_maps,properties_names}.rs
	_ins timezone_provider-v0_2 0.2.6 src/data "${w}/temporal-${TEMPORAL_COMMIT}"/provider/src/data/*.rs.data
	_ins zoneinfo64-v0_3 0.3.0 src/data "${out}/zoneinfo64/zoneinfo64.res"
	unset -f _ins

	local dir
	for dir in "syn-v2/src/gen *.rs" "syn-v3/src/gen *.rs" read-fonts-v0_43/generated \
		read-fonts-v0_43/data/generated write-fonts-v0_52/generated \
		icu_{calendar,locale,normalizer,properties}_data-v2/data; do
		[[ -d ${ED}${root}/${dir%% *} ]] || die "${dir%% *} not installed"
		echo "${dir}" >> "${dirs}" || die
	done
}
