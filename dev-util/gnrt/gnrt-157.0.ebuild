# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Chromium's gnrt, which writes the BUILD.gn files of the Rust crates Chromium
# vendors (third_party/rust/) from their Cargo metadata and gnrt_config.toml.
# Chromium checks that output in; the Chromium ebuild runs `gnrt gen` instead.
# gnrt is part of Chromium's tree (tools/crates/gnrt), so its sources come from
# the Chromium tarball; one slot per Chromium major version.
CHROMIUM_TARBALL_PV="157.0.8103.15"

# gnrt's Cargo.lock without the crates of its downloader (see
# files/gnrt-156-no-download.patch), minus CARGO_STUB_CRATES.
CRATES="
	ahash@0.8.12
	anstream@0.6.18
	anstyle-parse@0.2.6
	anstyle-query@1.1.2
	anstyle@1.0.10
	anyhow@1.0.98
	bitflags@2.9.0
	block-buffer@0.10.4
	camino@1.2.6
	cargo-platform@0.2.0
	cargo-platform@0.3.3
	cargo_metadata@0.23.1
	cfg-expr@0.20.9
	cfg-if@1.0.5
	clap@4.5.37
	clap_builder@4.5.37
	clap_derive@4.5.32
	clap_lex@0.7.4
	colorchoice@1.0.3
	cpufeatures@0.2.17
	crossbeam-deque@0.8.6
	crossbeam-epoch@0.9.18
	crossbeam-utils@0.8.21
	crypto-common@0.1.6
	darling@0.20.11
	darling_core@0.20.11
	darling_macro@0.20.11
	debug-ignore@1.0.5
	derive_builder@0.20.2
	derive_builder_core@0.20.2
	derive_builder_macro@0.20.2
	diff@0.1.13
	digest@0.10.7
	either@1.15.0
	env_filter@0.1.3
	env_logger@0.11.8
	equivalent@1.0.2
	errno@0.3.11
	fastrand@2.3.0
	fixedbitset@0.5.7
	fnv@1.0.7
	foldhash@0.1.5
	generic-array@0.14.7
	getrandom@0.3.2
	glob@0.3.3
	guppy-workspace-hack@0.1.0
	guppy@0.19.0
	handlebars@6.3.2
	hashbrown@0.15.5
	hashbrown@0.17.1
	heck@0.5.0
	ident_case@1.0.1
	indexmap@2.14.2
	is_terminal_polyfill@1.70.1
	itertools@0.14.0
	itertools@0.15.0
	itoa@1.0.15
	libc@0.2.172
	linux-raw-sys@0.9.4
	log@0.4.27
	memchr@2.7.4
	nested@0.1.1
	num-modular@0.6.1
	num-order@1.2.0
	once_cell@1.21.4
	pathdiff@0.2.3
	pest@2.8.0
	pest_derive@2.8.0
	pest_generator@2.8.0
	pest_meta@2.8.0
	petgraph@0.8.3
	pretty_assertions@1.4.1
	prettyplease@0.2.32
	proc-macro2@1.0.103
	quote@1.0.40
	rayon-core@1.13.0
	rayon@1.12.0
	rustix@1.0.7
	rustversion@1.0.20
	semver@1.0.28
	serde@1.0.229
	serde_core@1.0.229
	serde_derive@1.0.229
	serde_json@1.0.151
	serde_spanned@0.6.8
	sha2@0.10.9
	smallvec@1.16.1
	spdx@0.12.0
	static_assertions@1.1.0
	strsim@0.11.1
	strum@0.27.1
	strum_macros@0.27.1
	syn@2.0.110
	syn@3.0.6
	target-lexicon@0.13.5
	target-spec@3.7.0
	tempfile@3.19.1
	thiserror-impl@2.0.12
	thiserror@2.0.12
	toml@0.8.22
	toml_datetime@0.6.9
	toml_datetime@0.7.3
	toml_edit@0.22.26
	toml_edit@0.23.7
	toml_parser@1.0.4
	toml_write@0.1.1
	toml_writer@1.0.4
	typenum@1.18.0
	ucd-trie@0.1.7
	unicode-ident@1.0.18
	utf8parse@0.2.2
	version_check@0.9.5
	winnow@0.7.13
	yansi@1.0.1
	zerocopy@0.8.57
	zmij@1.0.23
"

# Never built on Linux (see cargo-stubs.eclass).
CARGO_STUB_CRATES="
	anstyle-wincon@3.0.7
	r-efi@5.2.0
	wasi@0.14.2+wasi-0.2.4
	windows-sys@0.59.0
	windows-targets@0.52.6
	windows_aarch64_gnullvm@0.52.6
	windows_aarch64_msvc@0.52.6
	windows_i686_gnu@0.52.6
	windows_i686_gnullvm@0.52.6
	windows_i686_msvc@0.52.6
	windows_x86_64_gnu@0.52.6
	windows_x86_64_gnullvm@0.52.6
	windows_x86_64_msvc@0.52.6
	wit-bindgen-rt@0.39.0
	zerocopy-derive@0.8.57
"

# Newest rust-version among the crates (guppy, target-spec, cargo-platform).
RUST_MIN_VER="1.91.0"

PYTHON_COMPAT=( python3_{12..15} )

inherit cargo cargo-stubs

DESCRIPTION="Chromium's generator of GN build files for its vendored Rust crates"
HOMEPAGE="https://chromium.googlesource.com/chromium/src/+/main/tools/crates/gnrt/"
SRC_URI="
	https://commondatastorage.googleapis.com/chromium-browser-official/chromium-${CHROMIUM_TARBALL_PV}-lite.tar.xz
	${CARGO_CRATE_URIS}
"
S="${WORKDIR}/chromium-${CHROMIUM_TARBALL_PV}/tools/crates/gnrt"

LICENSE="BSD"
# Dependent crate licenses
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions MIT Unicode-3.0 ZLIB"
SLOT="$(ver_cut 1)"
KEYWORDS="~amd64 ~arm64"
# Only `gnrt gen` is used, and Chromium's ebuild checks what it writes.
RESTRICT="test"

# Run time: `gnrt gen` runs `cargo metadata` (and `gn format`, which the Chromium
# ebuild has anyway).
RDEPEND="|| ( dev-lang/rust dev-lang/rust-bin )"

PATCHES=( "${FILESDIR}/${PN}-156-no-download.patch" )

src_unpack() {
	# Only gnrt (and the list of target triples its build script reads) from
	# Chromium's tarball.
	local top="chromium-${CHROMIUM_TARBALL_PV}"
	einfo "Unpacking gnrt from ${top}-lite.tar.xz ..."
	tar -xJf "${DISTDIR}/${top}-lite.tar.xz" -C "${WORKDIR}" \
		"${top}/tools/crates/gnrt" "${top}/build/rust/known-target-triples.txt" ||
		die "Failed to unpack gnrt"
	cargo_crate_unpack
	cargo_gen_config
	cargo_stub_crates
}

src_compile() {
	# Not --locked: the patch drops the downloader's crates, which cargo prunes
	# from Cargo.lock (offline, nothing else changes).
	cargo_src_compile --bin gnrt
}

src_install() {
	exeinto "/usr/lib/${PN}/${SLOT}"
	doexe "$(cargo_target_dir)"/gnrt
	dodoc README.md
}
