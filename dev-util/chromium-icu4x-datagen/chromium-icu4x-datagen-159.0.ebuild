# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Chromium's icu4x_datagen (tools/crates/icu4x_datagen), which writes the ICU4X
# baked data Chromium checks in (third_party/rust/icu4x_data, since 159) from
# CLDR, ICU's export data, Unicode's character data, the tzdb and the
# segmenter's LSTM models, filtered like Chromium's ICU data
# (third_party/icu/filters). The Chromium ebuild runs it instead of using the
# checked-in files. It is part of Chromium's tree, so its sources come from the
# Chromium tarball; one slot per Chromium major version.
CHROMIUM_TARBALL_PV="159.0.8154.4"

# icu4x_datagen's Cargo.lock as cargo prunes it with the patch (no downloader,
# no ICU4X compiled data), minus CARGO_STUB_CRATES.
CRATES="
	adler2@2.0.1
	aho-corasick@1.1.5
	anstream@1.0.0
	anstyle@1.0.14
	anstyle-parse@1.0.0
	anstyle-query@1.1.5
	anyhow@1.0.104
	autocfg@1.5.1
	bincode@1.3.3
	calendrical_calculations@0.2.4
	cfg-if@1.0.5
	clap@4.6.7
	clap_builder@4.6.7
	clap_derive@4.6.7
	clap_lex@1.1.1
	cobs@0.3.0
	colorchoice@1.0.5
	core_maths@0.1.1
	crc32fast@1.5.3
	crlify@1.0.5
	crossbeam-deque@0.8.8
	crossbeam-epoch@0.9.21
	crossbeam-utils@0.8.23
	databake@0.2.1
	databake-derive@0.2.2
	displaydoc@0.2.7
	either@1.19.0
	elsa@1.11.2
	embedded-io@0.4.0
	embedded-io@0.6.1
	env_filter@2.0.0
	env_logger@0.11.11
	equivalent@1.0.3
	erased-serde@0.4.10
	filetime@0.2.29
	fixed_decimal@0.7.3
	flate2@1.1.10
	hashbrown@0.17.1
	heck@0.5.0
	icu@2.4.0
	icu_calendar@2.4.0
	icu_casemap@2.4.0
	icu_collator@2.4.0
	icu_collections@2.4.0
	icu_datetime@2.4.0
	icu_decimal@2.4.0
	icu_experimental@0.7.0
	icu_list@2.4.0
	icu_locale@2.4.0
	icu_locale_core@2.4.0
	icu_locale_fallback@2.4.0
	icu_normalizer@2.4.0
	icu_pattern@0.5.1
	icu_plurals@2.4.0
	icu_properties@2.4.0
	icu_provider@2.4.0
	icu_provider_baked@2.4.0
	icu_provider_blob@2.4.0
	icu_provider_export@2.4.0
	icu_provider_fs@2.4.0
	icu_provider_registry@2.4.0
	icu_provider_source@2.4.0
	icu_segmenter@2.4.0
	icu_time@2.4.0
	indexmap@2.14.2
	is_terminal_polyfill@1.70.2
	itertools@0.14.0
	itoa@1.0.18
	ixdtf@0.6.7
	libc@0.2.191
	libm@0.2.16
	litemap@0.8.3
	log@0.4.34
	matrixmultiply@0.3.11
	memchr@2.8.3
	miniz_oxide@0.9.1
	ndarray@0.16.1
	num-bigint@0.4.8
	num-complex@0.4.6
	num-integer@0.1.47
	num-rational@0.4.2
	num-traits@0.2.19
	ordered-float@2.10.1
	parse-zoneinfo@0.5.0
	postcard@1.1.3
	potential_utf@0.1.6
	proc-macro2@1.0.107
	quote@1.0.47
	rawpointer@0.2.1
	rayon@1.12.0
	rayon-core@1.13.0
	regex@1.13.1
	regex-automata@0.4.18
	regex-syntax@0.8.11
	ryu@1.0.23
	serde@1.0.229
	serde-aux@4.7.0
	serde-json-core@0.6.0
	serde-value@0.7.0
	serde_core@1.0.229
	serde_derive@1.0.229
	serde_json@1.0.154
	serde_spanned@0.6.9
	simd-adler32@0.3.10
	smallvec@1.16.3
	stable_deref_trait@1.2.1
	strsim@0.11.1
	strum@0.28.0
	strum_macros@0.28.0
	syn@2.0.119
	syn@3.0.9
	synstructure@0.14.0
	tar@0.4.46
	thiserror@2.0.21
	thiserror-impl@2.0.21
	tinystr@0.8.5
	toml@0.8.23
	toml_datetime@0.6.11
	toml_edit@0.22.27
	toml_write@0.1.2
	twox-hash@2.1.5
	typed-path@0.12.4
	typeid@1.0.3
	unicode-ident@1.0.27
	utf16_iter@1.0.5
	utf8_iter@1.0.4
	utf8parse@0.2.2
	winnow@0.7.15
	write16@1.0.0
	writeable@0.6.4
	yoke@0.8.4
	yoke-derive@0.8.4
	zerofrom@0.1.8
	zerofrom-derive@0.1.8
	zerotrie@0.2.5
	zerovec@0.11.9
	zerovec-derive@0.11.7
	zip@9.0.5
	zmij@1.0.23
"

# Never built on Linux (see cargo-stubs.eclass).
CARGO_STUB_CRATES="
	anstyle-wincon@3.0.11
	bitflags@2.13.2
	cfg_aliases@0.2.2
	nix@0.31.3
	once_cell_polyfill@1.70.2
	portable-atomic@1.15.0
	portable-atomic-util@0.2.8
	windows-link@0.2.1
	windows-sys@0.61.2
"

# Newest rust-version among the crates (ICU4X 2.4, zip).
RUST_MIN_VER="1.88.0"

PYTHON_COMPAT=( python3_{12..15} )

inherit cargo cargo-stubs

DESCRIPTION="Chromium's generator of its ICU4X baked data"
HOMEPAGE="https://chromium.googlesource.com/chromium/src/+/main/tools/crates/icu4x_datagen/"
SRC_URI="
	https://commondatastorage.googleapis.com/chromium-browser-official/chromium-${CHROMIUM_TARBALL_PV}-lite.tar.xz
	${CARGO_CRATE_URIS}
"
S="${WORKDIR}/chromium-${CHROMIUM_TARBALL_PV}/tools/crates/icu4x_datagen"

LICENSE="BSD"
# Dependent crate licenses
LICENSE+=" Apache-2.0 MIT Unicode-3.0 || ( MIT Unlicense )"
SLOT="$(ver_cut 1)"
KEYWORDS="~amd64 ~arm64"
# Its tests need upstream's source data from the network.
RESTRICT="test"

PATCHES=( "${FILESDIR}/${PN}-159-local-sources.patch" )

src_unpack() {
	# Only icu4x_datagen from Chromium's tarball.
	local top="chromium-${CHROMIUM_TARBALL_PV}"
	einfo "Unpacking icu4x_datagen from ${top}-lite.tar.xz ..."
	tar -xJf "${DISTDIR}/${top}-lite.tar.xz" -C "${WORKDIR}" "${top}/tools/crates/icu4x_datagen" ||
		die "Failed to unpack icu4x_datagen"
	cargo_crate_unpack
	cargo_gen_config
	cargo_stub_crates
}

src_compile() {
	# Not --locked: the patch drops the downloader's crates and ICU4X's data crates, which cargo
	# prunes from Cargo.lock (offline, nothing else changes).
	cargo_src_compile --bin icu4x_datagen
}

src_install() {
	exeinto "/usr/lib/${PN}/${SLOT}"
	doexe "$(cargo_target_dir)"/icu4x_datagen
}
