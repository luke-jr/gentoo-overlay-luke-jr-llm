# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Converts CDDL to TypeScript and Zod schemas. Chromium's WebDriver BiDi
# implementation (third_party/chromium-bidi) checks the output for the CDDL of
# the WebDriver BiDi specs in; the Chromium ebuild runs cddlconv instead.
CRATES="
	abnf@0.12.0
	abnf-core@0.5.0
	abnf_to_pest@0.5.1
	aho-corasick@1.1.3
	android-tzdata@0.1.1
	android_system_properties@0.1.5
	anstream@0.6.18
	anstyle@1.0.10
	anstyle-parse@0.2.6
	anstyle-query@1.1.2
	anstyle-wincon@3.0.7
	anyhow@1.0.102
	arrayvec@0.5.2
	autocfg@1.4.0
	base16@0.2.1
	base45@3.1.0
	base64@0.22.1
	base64-url@3.0.0
	bitflags@2.9.0
	block-buffer@0.10.4
	bumpalo@3.17.0
	cc@1.2.16
	cddl@0.10.1
	cfg-if@1.0.0
	chrono@0.4.40
	ciborium@0.2.2
	ciborium-io@0.2.2
	ciborium-ll@0.2.2
	clap@4.5.60
	clap_builder@4.5.60
	clap_derive@4.5.55
	clap_lex@1.1.0
	codespan-reporting@0.12.0
	colorchoice@1.0.3
	console@0.15.11
	console_error_panic_hook@0.1.7
	convert_case@0.8.0
	core-foundation-sys@0.8.7
	cpufeatures@0.2.17
	crossterm@0.28.1
	crossterm_winapi@0.9.1
	crunchy@0.2.3
	crypto-common@0.1.6
	data-encoding@2.8.0
	deranged@0.5.5
	digest@0.10.7
	displaydoc@0.2.5
	either@1.15.0
	encode_unicode@1.0.0
	errno@0.3.13
	fastrand@2.3.0
	fnv@1.0.7
	generic-array@0.14.7
	getrandom@0.3.4
	half@2.5.0
	hashbrown@0.12.3
	heck@0.5.0
	hex@0.4.3
	hexf-parse@0.2.1
	iana-time-zone@0.1.61
	iana-time-zone-haiku@0.1.2
	indexmap@1.9.3
	insta@1.46.3
	is_terminal_polyfill@1.70.1
	itertools@0.10.5
	itertools@0.14.0
	itoa@1.0.15
	js-sys@0.3.77
	lazy_static@1.5.0
	lexical-core@1.0.5
	lexical-parse-float@1.0.5
	lexical-parse-integer@1.0.5
	lexical-util@1.0.6
	lexical-write-float@1.0.5
	lexical-write-integer@1.0.5
	libc@0.2.171
	linux-raw-sys@0.11.0
	linux-raw-sys@0.4.15
	lock_api@0.4.12
	log@0.4.26
	memchr@2.7.4
	minicov@0.3.7
	minimal-lexical@0.2.1
	mio@1.0.4
	nom@7.1.3
	num-conv@0.1.0
	num-traits@0.2.19
	num_threads@0.1.7
	once_cell@1.21.1
	parking_lot@0.12.3
	parking_lot_core@0.9.10
	pest@2.8.1
	pest_meta@2.8.1
	pest_vm@2.8.1
	powerfmt@0.2.0
	pretty@0.11.3
	proc-macro2@1.0.94
	quote@1.0.40
	r-efi@5.3.0
	redox_syscall@0.5.10
	regex@1.11.1
	regex-automata@0.4.9
	regex-syntax@0.8.5
	rustix@0.38.44
	rustix@1.1.2
	rustversion@1.0.20
	ryu@1.0.20
	same-file@1.0.6
	scopeguard@1.2.0
	serde@1.0.219
	serde-wasm-bindgen@0.6.5
	serde_derive@1.0.219
	serde_json@1.0.140
	sha2@0.10.8
	shlex@1.3.0
	signal-hook@0.3.17
	signal-hook-mio@0.2.4
	signal-hook-registry@1.4.2
	similar@2.7.0
	simplelog@0.12.2
	smallvec@1.14.0
	static_assertions@1.1.0
	strsim@0.11.1
	syn@2.0.100
	tempfile@3.23.0
	termcolor@1.4.1
	thiserror@2.0.12
	thiserror-impl@2.0.12
	time@0.3.44
	time-core@0.1.6
	time-macros@0.2.24
	typed-arena@2.0.2
	typenum@1.18.0
	ucd-trie@0.1.7
	unicode-ident@1.0.18
	unicode-segmentation@1.12.0
	unicode-width@0.1.14
	uriparse@0.6.4
	utf8parse@0.2.2
	version_check@0.9.5
	walkdir@2.5.0
	wasi@0.11.0+wasi-snapshot-preview1
	wasip2@1.0.2+wasi-0.2.9
	wasm-bindgen@0.2.100
	wasm-bindgen-backend@0.2.100
	wasm-bindgen-futures@0.4.50
	wasm-bindgen-macro@0.2.100
	wasm-bindgen-macro-support@0.2.100
	wasm-bindgen-shared@0.2.100
	wasm-bindgen-test@0.3.50
	wasm-bindgen-test-macro@0.3.50
	web-sys@0.3.77
	winapi@0.3.9
	winapi-i686-pc-windows-gnu@0.4.0
	winapi-util@0.1.9
	winapi-x86_64-pc-windows-gnu@0.4.0
	windows-core@0.52.0
	windows-link@0.1.0
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
	wit-bindgen@0.51.0
"

# Newest rust-version among the crates (clap_lex).
RUST_MIN_VER="1.85.0"

inherit cargo

DESCRIPTION="Converts CDDL definitions to TypeScript types and Zod schemas"
HOMEPAGE="https://github.com/google/cddlconv"
SRC_URI="
	https://static.crates.io/crates/${PN}/${P}.crate
	${CARGO_CRATE_URIS}
"

LICENSE="Apache-2.0"
# Dependent crate licenses
LICENSE+=" Apache-2.0-with-LLVM-exceptions Boost-1.0 CC0-1.0 MIT Unicode-3.0 Unlicense"
# One slot per version (the output differs between versions): bin/cddlconv-<version>.
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"

src_compile() {
	cargo_src_compile --bin "${PN}"
}

src_install() {
	newbin "$(cargo_target_dir)/${PN}" "${PN}-${PV}"
	dodoc README.md
}
