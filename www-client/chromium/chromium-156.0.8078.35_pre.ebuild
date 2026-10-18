# Copyright 2009-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# PACKAGING NOTES

# Upstream roll their bundled Clang every two weeks, and the bundled Rust
# is rolled regularly and depends on that. While we do our best to build
# with system Clang, we may eventually hit the point where we need to use
# the bundled Clang due to the use of prerelease features.

# USE=bundled-toolchain is intended for users who want to use the same toolchain
# as the upstream releases. It's also a good fallback in case we fall behind
# and need to get a release out quickly (less likely with `dev` in-tree).
# We can't rely on it as a default since the toolchain is only shipped for x86-64;
# other architectures will need to use system toolchain.

# Since m133 we are using CI-generated tarballs from
# https://github.com/chromium-linux-tarballs/chromium-tarballs/

# These are bit-for-bit identical to the official releases, but are built
# using an external CI system that we have some control over, in case
# issues pop up again with official tarball generation.

GN_MIN_VER=0.2578
# chromium-tools/get-chromium-toolchain-strings.py (or just use Chromicler)
# Node for M145+ should be 24.12.0 but that's not packaged in Gentoo yet. See #969145
TEST_FONT="9c07d19d9c5ee1ff94f717e6fb17e0c8c354e6f9"
BUNDLED_CLANG_VER="llvmorg-24-init-7747-g62397f8b-53"
BUNDLED_RUST_VER="1edd55dcfcd573872c727fa3e086369a71661ee0-2"
RUST_SHORT_HASH=${BUNDLED_RUST_VER:0:10}-${BUNDLED_RUST_VER##*-}
NODE_VER="24.12.0"
GO_MIN_VER="1.25.0"
ESBUILD_VER="0.28.2"
# TypeScript 7 compiler (tsgo); third_party/typescript/linux-amd64/src/package.json
TSGO_VER="7.0.2"
# DevTools' build (front_end/core/i18n/collect-ui-strings.js) uses TypeScript's JavaScript API,
# from its own copy of TypeScript 6; its prebuilt lib/typescript.js is replaced by dev-lang/typescript's.
DEVTOOLS_TS_VER="6.0.2"
# Polymer (third_party/polymer/v3_0): its bundle, polymer_bundled.min.js, is rebuilt from source.
POLYMER_VER="3.5.0"
SHADYCSS_VER="1.9.1"
SHADYCSS_COMMIT="4e6ebea7f179d131a1a6c98e38b7d038d0543699" # tag v1.9.1, npm's gitHead for 1.9.1
# Rollup (@rollup/wasm-node) in third_party/node/node_modules, used for WebUI bundling, is
# replaced by dev-util/rollup (built from source). chromium-bidi bundles its own, newer copy
# (ROLLUP_BIDI_VER), which is replaced by the same one (see src_prepare).
ROLLUP_VER="4.21.0"
ROLLUP_BIDI_VER="4.63.1"
VIRTUALX_REQUIRED="pgo"

CHROMIUM_LANGS="af am ar bg bn ca cs da de el en-GB es es-419 et fa fi fil fr gu he
	hi hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr
	sv sw ta te th tr uk ur vi zh-CN zh-TW"

# LLVM 23 means dev-lang/rust:1.99.0, which also needs a dev-util/crubit:1.99.0
# (Crubit is tied to one Rust build); add 23 together with that.
LLVM_COMPAT=( 22 )
PYTHON_COMPAT=( python3_{11..14} )
PYTHON_REQ_USE="xml(+)"
RUST_MIN_VER=1.98.1 # Oldest Rust with a dev-util/crubit slot (rustc driver, tied to the Rust build)
RUST_NEEDS_LLVM="yes please"
RUST_OPTIONAL="yes" # Not actually optional, but we don't need system Rust (or LLVM) with USE=bundled-toolchain
RUST_REQ_USE="rustfmt" # Upstream run rustfmt on bindgen output, so we need it to be available.

inherit check-reqs chromium-2 desktop flag-o-matic llvm-r1 multiprocessing ninja-utils pax-utils
inherit python-any-r1 readme.gentoo-r1 rust systemd toolchain-funcs virtualx xdg-utils

DESCRIPTION="Open-source version of Google Chrome web browser"
HOMEPAGE="https://www.chromium.org/"
PPC64_HASH="7aae8a84e327fc2078ce1625c9c70bfda77d626f"
COPIUM_COMMIT="027d15ffdcd1816b7935cee9ea4a4f6bae0bbe60"
# 156.0.8078.35 has no Linux release, and so no source tarball, yet (it shipped as Early Stable
# for Windows and Mac only). It is built from the 156.0.8078.12 tarball plus the upstream
# changes between the two tags, limited to what can affect a Linux build (see the header of
# files/chromium-156.0.8078.12-to-35.patch). Drop this once the real 156.0.8078.35 is out.
# Fixes that came later are applied on top (src_prepare).
CHROMIUM_TARBALL_PV="156.0.8078.12"
S="${WORKDIR}/chromium-${CHROMIUM_TARBALL_PV}"
SRC_URI="https://github.com/chromium-linux-tarballs/chromium-tarballs/releases/download/${CHROMIUM_TARBALL_PV}/chromium-${CHROMIUM_TARBALL_PV}-linux.tar.xz
	https://github.com/Polymer/polymer/archive/refs/tags/v${POLYMER_VER}.tar.gz
		-> polymer-${POLYMER_VER}.gh.tar.gz
	https://github.com/webcomponents/shadycss/archive/${SHADYCSS_COMMIT}.tar.gz
		-> shadycss-${SHADYCSS_COMMIT}.gh.tar.gz
	!bundled-toolchain? (
		https://codeberg.org/selfisekai/copium/archive/${COPIUM_COMMIT}.tar.gz
			-> chromium-patches-copium-${COPIUM_COMMIT:0:10}.tar.gz
	)
	bundled-toolchain? (
		https://commondatastorage.googleapis.com/chromium-browser-clang/Linux_x64/clang-${BUNDLED_CLANG_VER}.tar.xz
			-> chromium-clang-${BUNDLED_CLANG_VER}.tar.xz
		https://commondatastorage.googleapis.com/chromium-browser-clang/Linux_x64/rust-toolchain-${BUNDLED_RUST_VER}-${BUNDLED_CLANG_VER%-*}.tar.xz
			-> chromium-rust-toolchain-${RUST_SHORT_HASH}-${BUNDLED_CLANG_VER%-*}.tar.xz
	)
	test? (
		https://chromium-fonts.storage.googleapis.com/${TEST_FONT} -> chromium-testfonts-${TEST_FONT:0:10}.tar.gz
	)
	ppc64? (
		https://gitlab.raptorengineering.com/raptor-engineering-public/chromium/openpower-patches/-/archive/${PPC64_HASH}/openpower-patches-${PPC64_HASH}.tar.bz2 -> chromium-openpower-${PPC64_HASH:0:10}.tar.bz2
	)
	pgo? ( https://github.com/elkablo/chromium-profiler/releases/download/v0.2/chromium-profiler-0.2.tar )"

# The sources of the CDDL chromium-bidi makes its protocol types from (its
# tools/update_bidi_types.py): the specs' sources at the commits current when
# its checked-in types were last regenerated, and the extraction script of the
# WebDriver BiDi spec. Repository, commit, files (see src_prepare).
CHROMIUM_BIDI_SPECS="
	w3c/webdriver-bidi:ff4f83dfae2c8c51482acd503c50fb5abfac2cca:index.bs,scripts/cddl/generate.js,scripts/cddl/utils.js
	w3c/permissions:0051a836a92c4f8e37d016f261bbbed5b6312b96:index.html
	WebBluetoothCG/web-bluetooth:2e451c162f6a3f2277f86104223de4630710506e:index.bs
	WICG/nav-speculation:55f0c9565659d4af2fda2cb93060c17a04feb7fd:prefetch.bs
	WICG/ua-client-hints:6cf1025597fe4ee96063f32e94442613a7fa77f9:index.bs
	w3c-fedid/digital-credentials:b31343b4890a39ad3aa6d2bf066db1069458da4f:index.html
"
for _s in ${CHROMIUM_BIDI_SPECS}; do
	_p=( ${_s//:/ } ) # repository commit files
	for _f in ${_p[2]//,/ }; do
		SRC_URI+=" https://raw.githubusercontent.com/${_p[0]}/${_p[1]}/${_f}
			-> chromium-bidi-${_p[0]#*/}-${_p[1]:0:10}-${_f//\//-}"
	done
done
unset _s _p _f

# https://gitweb.gentoo.org/proj/chromium-tools.git/tree/get-chromium-licences.py @ 155.0.8059.40
# (newest SPDX data available for M156 at the time), merged with the previous list.
LICENSE="Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL Old-MIT PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
LICENSE+=" rar? ( unRAR )"

SLOT="stable"
KEYWORDS="~amd64 ~arm64"

IUSE_SYSTEM_LIBS="+system-harfbuzz +system-icu +system-zstd"
IUSE="+X ${IUSE_SYSTEM_LIBS} bindist bundled-toolchain cups debug ffmpeg-chromium gtk4 +hangouts headless kerberos +lto +official pax-kernel pgo"
IUSE+=" +proprietary-codecs pulseaudio qt6 +rar +screencast selinux test +vaapi +wayland +widevine cpu_flags_ppc_vsx3"
IUSE+=" hardened"
RESTRICT="
	!bindist? ( bindist )
	!test? ( test )
	arm64? ( test )" # Tests require CFI, which requires LTO, which is broken on arm64 with LLVM 21.

REQUIRED_USE="
	!headless? ( || ( X wayland ) )
	pgo? ( X !wayland )
	screencast? ( wayland )
	ffmpeg-chromium? ( bindist proprietary-codecs )
	test? ( lto )
"

COMMON_X_DEPEND="
	x11-libs/libXcomposite:=
	x11-libs/libXcursor:=
	x11-libs/libXdamage:=
	x11-libs/libXfixes:=
	>=x11-libs/libXi-1.6.0:=
	x11-libs/libXrandr:=
	x11-libs/libXrender:=
	x11-libs/libXtst:=
	x11-libs/libxshmfence:=
"

# sys-libs/zlib: https://bugs.gentoo.org/930365; -ng is not compatible.
# We _could_ use the bundled minizip, but that's against policy.
COMMON_SNAPSHOT_DEPEND="
	system-icu? ( >=dev-libs/icu-73.0:= )
	>=dev-libs/libxml2-2.12.4:=[icu]
	dev-libs/nspr:=
	>=dev-libs/nss-3.26:=
	dev-libs/libxslt:=
	media-libs/fontconfig:=
	>=media-libs/freetype-2.11.0-r1:=
	system-harfbuzz? ( >=media-libs/harfbuzz-3:0=[icu(-)] )
	media-libs/libjpeg-turbo:=
	system-zstd? ( >=app-arch/zstd-1.5.5:= )
	>=media-libs/libwebp-0.4.0:=
	media-libs/mesa:=[gbm(+)]
	>=media-libs/openh264-2.6.0:=
	sys-libs/zlib:=
	!headless? (
		dev-libs/glib:2
		>=media-libs/alsa-lib-1.0.19:=
		pulseaudio? ( media-libs/libpulse:= )
		sys-apps/pciutils:=
		kerberos? ( virtual/krb5 )
		vaapi? ( >=media-libs/libva-2.7:=[X?,wayland?] )
		X? (
			x11-base/xorg-proto:=
			x11-libs/libX11:=
			x11-libs/libxcb:=
			x11-libs/libXext:=
		)
		x11-libs/libxkbcommon:=
		wayland? (
			screencast? ( media-video/pipewire:= )
			dev-libs/libffi:=
			dev-libs/wayland:=
		)
	)
"

COMMON_DEPEND="
	${COMMON_SNAPSHOT_DEPEND}
	app-arch/bzip2:=
	dev-libs/expat:=
	net-misc/curl[ssl]
	sys-apps/dbus:=
	media-libs/flac:=
	sys-libs/zlib:=[minizip]
	!headless? (
		>=app-accessibility/at-spi2-core-2.46.0:2
		media-libs/mesa:=[X?,wayland?]
		virtual/udev
		x11-libs/cairo:=
		x11-libs/gdk-pixbuf:2
		x11-libs/pango:=
		cups? ( >=net-print/cups-1.3.11:= )
		qt6? ( dev-qt/qtbase:6[gui,widgets] )
		X? ( ${COMMON_X_DEPEND} )
	)
"
RDEPEND="${COMMON_DEPEND}
	!www-client/chromium:0
	>=www-client/chromium-common-2
	!headless? (
		|| (
			x11-libs/gtk+:3[X?,wayland?]
			gui-libs/gtk:4[X?,wayland?]
		)
		qt6? ( dev-qt/qtbase:6[X?,wayland?] )
	)
	virtual/ttf-fonts
	selinux? ( sec-policy/selinux-chromium )
	bindist? (
		!ffmpeg-chromium? ( >=media-video/ffmpeg-6.1-r1:0/58.60.60[chromium] )
		ffmpeg-chromium? ( media-video/ffmpeg-chromium:${PV%%\.*} )
	)
"
# PipeWire is only needed with USE=screencast (see COMMON_DEPEND), thanks to enable_remoting=false.
DEPEND="${COMMON_DEPEND}
	!headless? (
		gtk4? ( gui-libs/gtk:4[X?,wayland?] )
		!gtk4? ( x11-libs/gtk+:3[X?,wayland?] )
	)
"

BDEPEND="
	${COMMON_SNAPSHOT_DEPEND}
	${PYTHON_DEPS}
	$(python_gen_any_dep '
		dev-python/setuptools[${PYTHON_USEDEP}]
		!bundled-toolchain? ( dev-python/clang[${PYTHON_USEDEP}] )
	')
	>=app-arch/gzip-1.7
	!headless? (
		qt6? ( dev-qt/qtbase:6 )
	)
	!bundled-toolchain? ( $(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}
		llvm-core/llvm:${LLVM_SLOT}
		llvm-core/lld:${LLVM_SLOT}
		=dev-python/clang-${LLVM_SLOT}*
		official? (
			!ppc64? ( llvm-runtimes/compiler-rt-sanitizers:${LLVM_SLOT}[cfi] )
		) ')
		${RUST_DEPEND}
		dev-util/crubit
	)
	pgo? (
		>=dev-python/selenium-3.141.0
		>=dev-util/web_page_replay_go-20220314
	)
	>=dev-util/bindgen-0.72.1
	>=dev-build/gn-${GN_MIN_VER}
	>=dev-lang/go-${GO_MIN_VER}
	app-alternatives/ninja
	dev-lang/perl
	>=dev-util/gperf-3.2
	dev-util/esbuild:${ESBUILD_VER}
	dev-lang/typescript:${TSGO_VER}
	dev-lang/typescript:${DEVTOOLS_TS_VER}
	dev-util/rollup:${ROLLUP_VER}
	dev-util/chromium-node-modules:${PV%%.*}
	~dev-util/cddlconv-0.1.12
	dev-libs/protobuf
	dev-vcs/git
	>=net-libs/nodejs-${NODE_VER}[inspector]
	sys-apps/hwdata
	>=sys-devel/bison-2.4.3
	sys-devel/flex
	virtual/pkgconfig
	x11-misc/xdg-utils
"

if ! has chromium_pkg_die ${EBUILD_DEATH_HOOKS}; then
	EBUILD_DEATH_HOOKS+=" chromium_pkg_die";
fi

DISABLE_AUTOFORMATTING="yes"
DOC_CONTENTS="
Some web pages may require additional fonts to display properly.
Try installing some of the following packages if some characters
are not displayed properly:
- media-fonts/arphicfonts
- media-fonts/droid
- media-fonts/ipamonafont
- media-fonts/noto
- media-fonts/ja-ipafonts
- media-fonts/takao-fonts
- media-fonts/wqy-microhei
- media-fonts/wqy-zenhei

To fix broken icons on the Downloads page, you should install an icon
theme that covers the appropriate MIME types, and configure this as your
GTK+ icon theme.

For native file dialogs in KDE, install kde-apps/kdialog.

To make password storage work with your desktop environment you may
have install one of the supported credentials management applications:
- app-crypt/libsecret (GNOME)
- kde-frameworks/kwallet (KDE)
If you have one of above packages installed, but don't want to use
them in Chromium, then add --password-store=basic to CHROMIUM_FLAGS
in /etc/chromium/default.
"

python_check_deps() {
	python_has_version "dev-python/setuptools[${PYTHON_USEDEP}]" || return 1
	# V8 metagen uses the libclang Python bindings (see src_configure)
	if use !bundled-toolchain; then
		python_has_version "dev-python/clang[${PYTHON_USEDEP}]" || return 1
	fi
}

pre_build_checks() {
	# Check build requirements: bugs #471810, #541816, #914220
	# We're going to start doing maths here on the size of an unpacked source tarball,
	# this should make updates easier as chromium continues to balloon in size.
	# xz -l /var/cache/distfiles/chromium-${CHROMIUM_TARBALL_PV}*.tar.xz
	local base_disk=9 # Round up
	use test && base_disk=$((base_disk + 5))
	local extra_disk=1 # Always include a little extra space
	local memory=4
	tc-is-cross-compiler && extra_disk=$((extra_disk * 2))
	if use lto || use pgo; then
		memory=$((memory * 2 + 1))
		tc-is-cross-compiler && extra_disk=$((extra_disk * 2)) # Double the requirements
		use pgo && extra_disk=$((extra_disk + 4))
	fi
	if is-flagq '-g?(gdb)?([1-9])'; then
		if use custom-cflags; then
			extra_disk=$((extra_disk + 5))
		fi
		memory=$((memory * 2))
	fi
	local CHECKREQS_MEMORY="${memory}G"
	local CHECKREQS_DISK_BUILD="$((base_disk + extra_disk))G"
	check-reqs_${EBUILD_PHASE_FUNC}
}

pkg_pretend() {
	if [[ ${MERGE_TYPE} != binary ]]; then
		# The pre_build_checks are all about compilation resources, no need to run it for a binpkg
		pre_build_checks
	fi

	if use headless; then
		local headless_unused_flags=("cups" "kerberos" "pulseaudio" "qt6" "vaapi" "wayland")
		for myiuse in ${headless_unused_flags[@]}; do
			use ${myiuse} && ewarn "Ignoring USE=${myiuse}, USE=headless is set."
		done
	fi

	if ! use bindist && use ffmpeg-chromium; then
		ewarn "Ignoring USE=ffmpeg-chromium, USE=bindist is not set."
	fi
}

pkg_setup() {
	if [[ ${MERGE_TYPE} != binary ]]; then
		# The pre_build_checks are all about compilation resources, no need to run it for a binpkg
		pre_build_checks

		# LTO is selected with USE=lto (Chromium's ThinLTO, set up by GN), not by -flto in CFLAGS.
		local want_lto="false"
		use lto && want_lto="true"

		# The linux:unbundle toolchain in GN grabs CC, CXX, CPP (etc) from the environment
		# We'll set these to clang here then use llvm-utils functions to very explicitly set these
		# to a sane value.
		# This is effectively the 'force-clang' path if GCC support is re-added.
		if use !bundled-toolchain; then
			llvm-r1_pkg_setup
			rust_pkg_setup

			# Crubit (cc_bindings_from_rs, upstream's C++ bindings generator for Rust code;
			# needed by e.g. Blink's font format check and the Web Bundle parser) is a
			# rustc driver: it must be linked against the very same dev-lang/rust build
			# whose rustc and stdlib we use. dev-util/crubit is slotted by Rust slot.
			if [[ ${RUST_TYPE} != source ]]; then
				eerror "dev-util/crubit is built against dev-lang/rust, but Rust ${RUST_SLOT} (${RUST_TYPE}) was selected."
				eerror "Install dev-lang/rust:${RUST_SLOT}, or select another Rust with ERUST_SLOT_OVERRIDE/ERUST_TYPE_OVERRIDE."
				die "Crubit requires dev-lang/rust (not rust-bin)"
			fi
			if ! has_version -b "dev-util/crubit:${RUST_SLOT}"; then
				eerror "dev-util/crubit:${RUST_SLOT} is required to build with Rust ${RUST_SLOT}."
				eerror "Install it, or select a Rust slot that has it with ERUST_SLOT_OVERRIDE."
				die "dev-util/crubit:${RUST_SLOT} is not installed"
			fi
			"${BROOT}/usr/lib/crubit/${RUST_SLOT}/bin/cc_bindings_from_rs" --help >/dev/null ||
				die "cc_bindings_from_rs does not run; rebuild dev-util/crubit:${RUST_SLOT} (dev-lang/rust:${RUST_SLOT} was probably rebuilt)"

			if tc-ld-is-mold; then
				ewarn "Mold is currently not supported, it will not be used"
			fi

			# Forcing clang; respect llvm_slot_x to enable selection of impl via LLVM_COMPAT
			AR=llvm-ar
			CPP="${CHOST}-clang++-${LLVM_SLOT} -E"
			NM=llvm-nm
			CC="${CHOST}-clang-${LLVM_SLOT}"
			CXX="${CHOST}-clang++-${LLVM_SLOT}"
		fi

		# LTO in Chromium means LLVM ThinLTO, if GCC support is re-added
		# We'll need to handle that here too.
		use_lto="false"
		local lto_usable="true"
		if [[ "$want_lto" == "true" ]]; then
			if use arm64 && [[ "${LLVM_SLOT}" -lt 22 ]]; then
				einfo "LTO is broken with LLVM 21 on arm64, ignoring USE=lto."
				lto_usable="false"
			else
				use_lto="true"
			fi
		fi
		# GN sets up (Thin)LTO itself; -flto in CFLAGS would only slow the build down.
		filter-lto

		if [[ "$use_lto" == "false" ]] && use official && [[ "$lto_usable" == "true" ]]; then
			einfo "USE=official selected without USE=lto."
			einfo "It is _highly_ recommended that LTO be enabled for performance reasons"
			einfo "and to be consistent with the upstream \"official\" build optimisations."
		fi

		if [[ "$use_lto" == "false" ]] && use test; then
			die "Tests require CFI which requires LTO"
		fi

		export use_lto

		if tc-is-cross-compiler; then
			use pgo && die "The pgo USE flag cannot be used when cross-compiling"
			CPP="${CBUILD}-clang++-${LLVM_SLOT} -E"
		fi

		# I hate doing this but upstream Rust have yet to come up with a better solution for
		# us poor packagers. Required for Split LTO units, which are required for CFI,
		# and for Crubit (a rustc driver) and the unstable features its support crates use.
		export RUSTC_BOOTSTRAP=1

		# Sanity checks for development convenience
		if ver_test $(gn --version || die) -lt ${GN_MIN_VER}; then
			die "dev-build/gn >= ${GN_MIN_VER} is required to build this Chromium"
		fi

		# Sometimes, when adding a new LLVM slot, devs (me) forget to install an appropriate lld.
		if tc-ld-is-lld; then
			local lld_ver=$(ld.lld --version | awk '{split($2,a,"."); print a[1]}' || die "Failed to check lld version")
			if [[ ${lld_ver} -lt ${LLVM_SLOT} ]]; then
				die "Your lld version (${lld_ver}) is too old for the selected LLVM slot (${LLVM_SLOT}). Please install a newer lld or select an older LLVM slot."
			fi
		fi
	fi

	chromium_suid_sandbox_check_kernel_config
}

src_unpack() {
	unpack chromium-${CHROMIUM_TARBALL_PV}-linux.tar.xz
	unpack polymer-${POLYMER_VER}.gh.tar.gz shadycss-${SHADYCSS_COMMIT}.gh.tar.gz
	# These should only be required when we're not using the official toolchain
	if use !bundled-toolchain; then
		unpack chromium-patches-copium-${COPIUM_COMMIT:0:10}.tar.gz
	fi

	use pgo && unpack chromium-profiler-0.2.tar

	if use test; then
		# This just contains a bunch of font files that need to be unpacked (or moved) to the correct location.
		local testfonts_dir="${S}/third_party/test_fonts/test_fonts"
		local testfonts_tar="${DISTDIR}/chromium-testfonts-${TEST_FONT:0:10}.tar.gz"
		einfo "Unpacking test fonts ..."
		tar xf "${testfonts_tar}" -C "${testfonts_dir}" || die "Failed to unpack testfonts"
	fi

	# We need to manually unpack this since M126 else we'd unpack one toolchain over the other.
	# Since we're doing that anyway let's unpack to sensible locations to make symlink creation easier.
	if use bundled-toolchain; then
		einfo "Unpacking bundled Clang ..."
		mkdir -p "${WORKDIR}"/clang || die "Failed to create clang directory"
		tar xf "${DISTDIR}/chromium-clang-${BUNDLED_CLANG_VER}.tar.xz" -C "${WORKDIR}/clang" || die "Failed to unpack Clang"
		einfo "Unpacking bundled Rust ..."
		local rust_dir="${WORKDIR}/rust-toolchain"
		mkdir -p "${rust_dir}" || die "Failed to create rust toolchain directory"
		tar xf "${DISTDIR}/chromium-rust-toolchain-${RUST_SHORT_HASH}-${BUNDLED_CLANG_VER%-*}.tar.xz" -C "${rust_dir}" ||
			die "Failed to unpack Rust"
	fi

	if use ppc64; then
		unpack chromium-openpower-${PPC64_HASH:0:10}.tar.bz2
	fi
}

remove_compiler_builtins() {
	# We can't use the bundled compiler builtins with the system toolchain
	# We used to `grep` then `sed`, but it was indirect. Combining the two into a single
	# `awk` command is more efficient and lets us document the logic more clearly.

	local pattern='    configs += [ "//build/config/clang:compiler_builtins" ]'
	local target='build/config/compiler/BUILD.gn'

	local tmpfile
	tmpfile=$(mktemp) || die "Failed to create temporary file."

	if awk -v pat="${pattern}" '
	BEGIN {
		match_found = 0
	}

	# If the delete countdown is active, decrement it and skip to the next line.
	d > 0 { d--; next }

	# If the current line matches the pattern...
	$0 == pat {
		match_found = 1   # ...set our flag to true.
		d = 2             # Set delete counter for this line and the next two.
		prev = ""         # Clear the buffered previous line so it is not printed.
		next
	}

	# For any other line, print the buffered previous line.
	NR > 1 { print prev }

	# Buffer the current line to be printed on the next cycle.
	{ prev = $0 }

	END {
		# Print the last line if it was not part of a deleted block.
		if (d == 0) { print prev }

		# If the pattern was never found, exit with a failure code.
		if (match_found == 0) {
		exit 1
		}
	}
	' "${target}" > "${tmpfile}"; then
		# AWK SUCCEEDED (exit code 0): The pattern was found and edited.
		# This is to avoid gawk's `-i inplace` option which users complain about.
		mv "${tmpfile}" "${target}"
	else
		# AWK FAILED (exit code 1): The pattern was not found.
		rm -f "${tmpfile}"
		die "Awk patch failed: Pattern not found in ${target}."
	fi
}

src_prepare() {
	# Upgrade the ${CHROMIUM_TARBALL_PV} tarball to ${PV%_pre} first (see SRC_URI). It contains a
	# git binary patch (ICU data), which GNU patch (eapply) cannot apply.
	einfo "Upgrading the ${CHROMIUM_TARBALL_PV} sources to ${PV%_pre} ..."
	git apply --whitespace=nowarn "${FILESDIR}/chromium-${CHROMIUM_TARBALL_PV}-to-${PV%_pre}.patch" ||
		die "Failed to upgrade the sources to ${PV%_pre}"
	local version
	version=$(source chrome/VERSION && echo "${MAJOR}.${MINOR}.${BUILD}.${PATCH}") ||
		die "Failed to read chrome/VERSION"
	[[ ${version} == "${PV%_pre}" ]] || die "chrome/VERSION says ${version} after upgrading, expected ${PV%_pre}"

	# Security fixes newer than ${PV%_pre}: the later changes of its release branch (which
	# include CVE-2026-110913, -110918 and -110922 from Stable 155.0.8059.84), and the
	# CVE-2026-110914 fix 156 hasn't got yet. See the patch headers. Keep chrome/VERSION as is.
	einfo "Applying the 156 branch's fixes after ${PV%_pre} ..."
	local p
	for p in chromium-${PV%_pre}-branch-fixes.patch chromium-156-cve-2026-110914.patch; do
		git apply --whitespace=nowarn "${FILESDIR}/${p}" || die "Failed to apply ${p}"
	done

	# Calling this here supports resumption via FEATURES=keepwork
	python_setup

	# We'll fill this in as we go. Patches go in chromium-patches.
	local PATCHES=()

	PATCHES+=(
		"${FILESDIR}/chromium-patches-${PV%%.*}/common/"
		# Chromium must not download executable code at runtime (other than
		# what web pages themselves load): Widevine CDM, Screen AI, SODA,
		# TranslateKit, the WASM TTS engine, component-extension JS updates
		# and the remote DevTools front-end.
		"${FILESDIR}/chromium-156-no-runtime-executable-downloads.patch"
		"${FILESDIR}/chromium-156-v8-metagen-resource-dir.patch"
		# OpenXR includes <vulkan/vulkan.h> without depending on Chromium's Vulkan headers.
		"${FILESDIR}/chromium-156-openxr-vulkan-headers.patch"
		# GN arg enable_webui_lint, to skip the ESLint/Stylelint checks (see below).
		"${FILESDIR}/chromium-156-webui-lint-arg.patch"
		# ts-proto's protoc plugin comes from dev-util/chromium-node-modules (see below).
		"${FILESDIR}/chromium-156-ts-proto-from-source.patch"
		# Skia's AVX-512 kernels stay AVX-512 when CFLAGS contain -march.
		"${FILESDIR}/chromium-156-skia-avx512-feature-flags.patch"
		# Deterministic output for DevTools' NativeFunctions.ts generator (see below).
		"${FILESDIR}/chromium-156-devtools-natives-sorted.patch"
		# No terms dialog on a new profile's first run (from ungoogled-chromium).
		"${FILESDIR}/chromium-156-disable-tos-dialog.patch"
	)

	# So many fontconfig magic numbers to cover
	# TODO: once upstream roll to 2.18.2+ set that as our minimum and remove this logic.
	# <=2.17.1 -> 9
	# >2.17.1 && <2.18.2 -> 11
	# >=2.18.2 -> 12
	local fontconfig_cache_magic=9
	if has_version ">=media-libs/fontconfig-2.18.2"; then
		fontconfig_cache_magic=12
	elif has_version ">media-libs/fontconfig-2.17.1"; then
		fontconfig_cache_magic=11
	fi

	sed -E -i \
		-e "s#(fb5c91b2895aa445d23aebf7f9e2189c-le64\.cache-)(9|10|11|12)#\1${fontconfig_cache_magic}#g" \
		third_party/test_fonts/fontconfig/BUILD.gn || die "Failed to set fontconfig cache magic in BUILD.gn"

	sed -E -i \
		-e "s#(kCacheKey \+ \"/-le64\.cache-)(9|10|11|12)(\")#\1${fontconfig_cache_magic}\3#g" \
		-e "s#(kCacheKey \+ \"-le64\.cache-)(9|10|11|12)(\")#\1${fontconfig_cache_magic}\3#g" \
		third_party/test_fonts/fontconfig/generate_fontconfig_caches.cc || \
			die "Failed to set fontconfig cache magic in generate_fontconfig_caches.cc"

	if use bundled-toolchain; then
		# We need to symlink the toolchain into the expected location
		einfo "Symlinking Clang toolchain to expected location ..."
		mkdir -p third_party/llvm-build/ || die "Failed to create llvm-build directory"
		# the 'Chromium Linux Tarballs' seem to already have 'Release+Asserts/{lib,bin}'; not sure if this is an
		# upstream change - we're using the same scripts to build, theoretically. We'll still attempt to create
		# llvm-build, but we'll rm Release+Asserts and symlink directly.
		if [[ -d third_party/llvm-build/Release+Asserts ]]; then
			rm -r third_party/llvm-build/Release+Asserts || die "Failed to remove third_party/llvm-build/Release+Asserts"
		fi
		ln -s "${WORKDIR}"/clang third_party/llvm-build/Release+Asserts || die "Failed to bundle Clang"
		einfo "Symlinking Rust toolchain to expected location ..."
		# As above, so below
		if [[ -d third_party/rust-toolchain ]]; then
			rm -r third_party/rust-toolchain || die "Failed to remove third_party/rust-toolchain"
		fi
		ln -s "${WORKDIR}"/rust-toolchain third_party/rust-toolchain || die "Failed to bundle rust"
		cp "${WORKDIR}"/rust-toolchain/VERSION \
			"${WORKDIR}"/rust-toolchain/INSTALLED_VERSION || die "Failed to set rust version"
	else
		# We don't need our toolchain patches if we're using the official toolchain

		# Copium patches go here.
		PATCHES+=(
			"${WORKDIR}/copium/cr143-libsync-__BEGIN_DECLS.patch"
			"${WORKDIR}/copium/cr145-iwyu-dev_t.patch"
			"${WORKDIR}/copium/cr147-simdutf-8.0-base-char.patch"
			"${WORKDIR}/copium/cr148-rust-1.95-bytemuck.patch"
			"${WORKDIR}/copium/cr152-unbundle-minizip-undo-unicode.patch"
			"${WORKDIR}/copium/cr152-unbundle-opus-devtools.patch"
			"${WORKDIR}/copium/cr153-unbundle-opus-iamf.patch"
			"${WORKDIR}/copium/cr156-unbundle-icu-remoting.patch"
			"${WORKDIR}/copium/cr156-v8-no-san-trap.patch"
		)

		# Automate conditional application of chromium-patches
		# The directory structure is expected to be something like:
		# chromium-patches-145/
		# ├── toolchain/
		# │   ├── cr123-foo.patch
		# │   └── cr135-bar.patch
		# ├── llvm/
		# │   ├── cr144-baz.patch
		# │   └── lt-23/
		# │       └── cr145-bleeding-edge-llvm-feature.patch
		# Where `lt-23` means "apply this patch if the LLVM version is less than 23".
		# Only categories in `slot_map` will be checked for version constraints.
		shopt -s nullglob
		local -A slot_map=( [llvm]="${LLVM_SLOT}" [rust]="${RUST_SLOT}" )

		for category in "${FILESDIR}/chromium-patches-${PV%%.*}"/*/; do
			local category_name="${category%/}"
			category_name="${category_name##*/}"

			# Skip arch-specific categories
			if [[ "${category_name}" == "ppc64le" ]]; then
				use ppc64 || continue
			fi

			# We applied common patches above, no need to apply them again here
			[[ "${category_name}" == "common" ]] && continue

			# Unconditional patches for this category
			local category_patches=( "${category}"*.patch )
			[[ ${#category_patches[@]} -gt 0 ]] && PATCHES+=( "${category}" )

			# Version-constrained subdirectories (e.g., llvm/lt-23/)
			for constraint_dir in "${category}"*/; do
				local dir_name="${constraint_dir%/}"
				dir_name="${dir_name##*/}"
				if [[ "${dir_name}" =~ ^lt-(.*)$ && -v slot_map[${category_name}] ]]; then
					ver_test "${slot_map[${category_name}]}" -lt "${BASH_REMATCH[1]}" &&
						PATCHES+=( "${constraint_dir}" )
				fi
			done
		done

		shopt -u nullglob

		# Strictly speaking this doesn't need to be gated (no bundled toolchain for ppc64); it keeps the logic together
		if use ppc64; then
			local patchset_dir="${WORKDIR}/openpower-patches-${PPC64_HASH}/patches"
			# patch causes build errors on 4K page systems (https://bugs.gentoo.org/show_bug.cgi?id=940304)
			local page_size_patch="ppc64le/third_party/use-sysconf-page-size-on-ppc64.patch"
			local isa_3_patch="ppc64le/core/baseline-isa-3-0.patch"
			# Apply the OpenPOWER patches (check for page size and isa 3.0)
			openpower_patches=( $(grep -E "^ppc64le|^upstream" "${patchset_dir}/series" | grep -v "${page_size_patch}" |
				grep -v "${isa_3_patch}" || die) )
			for patch in "${openpower_patches[@]}"; do
				PATCHES+=( "${patchset_dir}/${patch}" )
			done
			if [[ $(getconf PAGESIZE) == 65536 ]]; then
				PATCHES+=( "${patchset_dir}/${page_size_patch}" )
			fi
			# We use vsx3 as a proxy for 'want isa3.0' (POWER9)
			if use cpu_flags_ppc_vsx3 ; then
				PATCHES+=( "${patchset_dir}/${isa_3_patch}" )
			fi
		fi

		# Use the system Crubit (dev-util/crubit) with the prebuilt system Rust stdlib
		# (generates the stdlib's C++ bindings from its .rmeta files); see the patch header.
		PATCHES+=( "${FILESDIR}/chromium-156-system-crubit.patch" )

		remove_compiler_builtins

		# We can't rely on the eselect'd Rust to actually include rustfmt, so we'll point to the selected slot specifically.
		local suffix=""
		if [[ "${RUST_TYPE}" == "binary" ]]; then
			suffix="-bin-${RUST_SLOT}"
		else
			suffix="-${RUST_SLOT}"
		fi
		sed -i "s|/bin/rustfmt|/bin/rustfmt${suffix}|g" build/rust/rust_bindgen_generator.gni ||
			die "Failed to update rustfmt path"

	fi

	if use hardened; then
		PATCHES+=(
			# Seccomp-BPF: no writable+executable memory in sandboxed processes that
			# don't need a JIT; renderers and V8-running service processes keep it
			# unless V8 runs jitless (JavaScript JIT disabled for the site) (from
			# Hexavalent / Vanadium; see the patch headers). Plus V8's WebAssembly
			# interpreter for sites with JIT disabled.
			"${FILESDIR}/chromium-156-hardened-0178-seccomp-restrict-dynamic-code.patch"
			"${FILESDIR}/chromium-156-hardened-0183-seccomp-restrict-dynamic-code-support.patch"
			"${FILESDIR}/chromium-156-hardened-0212-wasm-interpreter-without-jit.patch"
			# DrumBrake (v8_enable_drumbrake, below) doesn't build in 156 without this.
			"${FILESDIR}/chromium-156-hardened-v8-drumbrake-declares-locals.patch"
			# Page info bubble toggles for the JavaScript JIT and optimizer site
			# settings (JIT off makes the above apply to that site).
			"${FILESDIR}/chromium-156-hardened-page-info-jsjit.patch"
			"${FILESDIR}/chromium-156-hardened-page-info-jsopti.patch"
			# -fstack-protector-strong instead of -fstack-protector
			"${FILESDIR}/chromium-156-hardened-stack-protector-strong.patch"
			# From Vanadium, unchanged: component updates only over HTTPS; strict
			# origin isolation and origin-keyed processes; Local Network Access
			# checks for WebRTC; Certificate Transparency enforcement, using the
			# log list from the PKI Metadata component.
			"${FILESDIR}/chromium-156-hardened-vanadium-0120-require-https-component-updates.patch"
			"${FILESDIR}/chromium-156-hardened-vanadium-0127-strict-origin-isolation.patch"
			"${FILESDIR}/chromium-156-hardened-vanadium-0244-certificate-transparency.patch"
			"${FILESDIR}/chromium-156-hardened-vanadium-0245-local-network-access-checks.patch"
			"${FILESDIR}/chromium-156-hardened-vanadium-0250-origin-keyed-processes.patch"
			# From Vanadium, unchanged: Safe Browsing off by default (it can be turned
			# on in settings; SCT auditing for CT follows it), and no opt-in offer
			# for Safe Browsing extended reporting.
			"${FILESDIR}/chromium-156-hardened-vanadium-0086-no-safe-browsing-reporting-opt-in.patch"
			"${FILESDIR}/chromium-156-hardened-vanadium-0087-safe-browsing-off-by-default.patch"
		)
	fi

	default

	if use !bundled-toolchain; then
		# As for bindgen above; these files are added/changed by chromium-156-system-crubit.patch.
		sed -i "s|/bin/rustfmt|/bin/rustfmt${suffix}|g" build/rust/gni_impl/cpp_api_from_rust.gni \
			build/rust/std/prebuilt_std_bindings.gni || die "Failed to update rustfmt path for Crubit"
	fi

	# Sanity check esbuild version before we start removing files.
	# We _could_ patch the version check out - in theory esbuild upstream are being super conservative after
	# arch(AUR) packaged an `esbuild` binary and set ESBUILD_BINARY_PATH=/usr/bin/esbuild, causing much breakage,
	# but this is fine too and exactly matches what upstream are expecting.
	# https://github.com/evanw/esbuild/issues/2894
	local esbuild_js="${S}/third_party/devtools-frontend/src/node_modules/esbuild/lib/main.js"
	local found
	found=$(awk -F'"' '/if \(binaryVersion !==/ {print $2}' "${esbuild_js}")
	if [[ "${found}" != "${ESBUILD_VER}" ]]; then
		die "esbuild version mismatch: expected ${ESBUILD_VER}, found ${found}"
	fi

	# Likewise for the TypeScript 7 compiler (tsgo) used for all WebUI and
	# DevTools TypeScript; its prebuilt binary is replaced below.
	local tsgo_dir="${S}/third_party/typescript/linux-amd64/src/lib"
	found=$("${EPYTHON}" -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' \
		"${tsgo_dir}/../package.json") || die "Failed to read the bundled TypeScript version"
	if [[ "${found}" != "${TSGO_VER}" ]]; then
		die "TypeScript (tsgo) version mismatch: expected ${TSGO_VER}, found ${found}"
	fi

	# And for rollup, whose WebAssembly parser is replaced below (the parser's AST format
	# belongs to one rollup release). chromium-bidi's copy is replaced with WebUI's; a
	# different version there needs re-checking (see below).
	local -A rollup_dirs=(
		["${S}/third_party/node/node_modules/@rollup/wasm-node"]="${ROLLUP_VER}"
		["${S}/third_party/chromium-bidi/node_modules/@rollup/wasm-node"]="${ROLLUP_BIDI_VER}"
		# not rollup, but checked the same way
		["${S}/third_party/devtools-frontend/src/node_modules/typescript"]="${DEVTOOLS_TS_VER}"
	)
	found=$("${EPYTHON}" -c 'import json, sys; d = json.load(open(sys.argv[1]))["dependencies"]
print(d["@polymer/polymer"], d["@webcomponents/shadycss"])' "${S}/third_party/polymer/v3_0/package.json") ||
		die "Failed to read the Polymer version"
	[[ ${found} == "${POLYMER_VER} ${SHADYCSS_VER}" ]] ||
		die "Polymer/ShadyCSS version mismatch: expected ${POLYMER_VER} ${SHADYCSS_VER}, found ${found}"
	local rollup_dir
	for rollup_dir in "${!rollup_dirs[@]}"; do
		found=$("${EPYTHON}" -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' \
			"${rollup_dir}/package.json") || die "Failed to read the version in ${rollup_dir}"
		if [[ "${found}" != "${rollup_dirs[${rollup_dir}]}" ]]; then
			die "Version mismatch in ${rollup_dir}: expected ${rollup_dirs[${rollup_dir}]}, found ${found}"
		fi
	done

	# The tarball's node_modules directories (WebUI, chromium-bidi, DevTools) hold 1329 npm
	# packages, as npm publishes them: mostly generated JavaScript. Delete those the build
	# doesn't use (most of the rest are the ESLint/Stylelint checks, disabled below).
	einfo "Removing unused npm packages ..."
	"${EPYTHON}" "${FILESDIR}/chromium-prune-node-modules.py" "${S}" \
		"${FILESDIR}/chromium-${PV%%.*}-node-modules.txt" || die "Failed to remove unused npm packages"

	# Nothing prebuilt may be used for the build: delete all compiled code (ELF, PE, Mach-O,
	# WebAssembly, LLVM bitcode, SPIR-V, Java/Android bytecode, ...) and all archives, which could
	# hide it (none are build inputs; see files/chromium-binary-audit.py), then provide the few
	# tools the build needs from the system (below), and check the result.
	local binary_allowlist=()
	elog "Removing bundled binaries from source tree ..."
	"${EPYTHON}" "${FILESDIR}/chromium-binary-audit.py" --delete "${binary_allowlist[@]/#/--allow=}" \
		"${S}" > "${T}/binary-removal.log" || die "Failed to remove bundled binaries"

	# And now we restore any that we actually need, from the host system
	local esbuild_path="${S}/third_party/devtools-frontend/src/third_party/esbuild"
	local -A restore_list=(
		["/usr/bin/esbuild-${ESBUILD_VER}"]="${esbuild_path}/esbuild"
		["/usr/bin/gperf"]="${S}/third_party/gperf/cipd/bin/gperf"
		["/usr/bin/node"]="${S}/third_party/node/linux/node-linux-x64/bin/node"
	)

	for src in "${!restore_list[@]}"; do
		dst="${restore_list[${src}]}"
		if [[ -f "${src}" ]]; then
			einfo "Symlinking ${src} ..."
			# Make sure the parent dir exists; some tarballs don't include (e.g.) node's bindir
			mkdir -p "$(dirname "${dst}")" || die "Failed to create directory for ${dst}"
			# Replace whatever is left there (e.g. a stub or a symlink to /dev/null/INVALID put in
			# place by a user patch or hook instead of the deleted prebuilt binary).
			rm -f "${dst}" || die "Failed to remove ${dst}"
			ln -s "${src}" "${dst}" || die "Failed to symlink ${dst} from ${src}"
			if [[ ! -L "${dst}" || "$(readlink -f "${dst}")" != "${src}" ]]; then
				die "Symlink verification failed for ${dst} -> ${src}"
			fi
		else
			die "Expected to find ${src} to restore ${dst}, but it does not exist."
		fi
	done

	# chromium-bidi's protocol types and Zod schemas (src/protocol{,-parser}/generated) are made by
	# its tools/update_bidi_types.py with cddlconv from the CDDL in the WebDriver BiDi specs, which
	# the WebDriver BiDi spec's scripts/cddl/generate.js extracts (with parse5): regenerate them from
	# the specs' sources (CHROMIUM_BIDI_SPECS). Upstream formats the output with prettier and eslint
	# afterwards, which only changes the layout; that is left out.
	einfo "Regenerating chromium-bidi's protocol types ..."
	local bidi_spec bidi_p bidi_f bidi_d bidi_cddl="${T}/bidi-cddl" bidi_gen
	for bidi_spec in ${CHROMIUM_BIDI_SPECS}; do
		bidi_p=( ${bidi_spec//:/ } )
		for bidi_f in ${bidi_p[2]//,/ }; do
			bidi_d="${bidi_cddl}/${bidi_p[0]#*/}/src/${bidi_f}"
			mkdir -p "${bidi_d%/*}" || die
			cp "${DISTDIR}/chromium-bidi-${bidi_p[0]#*/}-${bidi_p[1]:0:10}-${bidi_f//\//-}" "${bidi_d}" || die
		done
	done
	bidi_gen="${bidi_cddl}/webdriver-bidi/src/scripts/cddl/generate.js"
	for bidi_spec in ${CHROMIUM_BIDI_SPECS}; do
		bidi_p=( ${bidi_spec//:/ } )
		bidi_f=${bidi_p[2]%%,*} # the spec's source
		# generate.js writes all.cddl (and local.cddl, remote.cddl) to the current directory.
		( cd "${bidi_cddl}/${bidi_p[0]#*/}" &&
			NODE_PATH="${S}/third_party/node/node_modules" node "${bidi_gen}" "src/${bidi_f}" ) ||
			die "Failed to extract the CDDL of ${bidi_p[0]}"
	done
	"${EPYTHON}" -B "${FILESDIR}/chromium-bidi-types.py" third_party/chromium-bidi "${bidi_cddl}" ||
		die "Failed to regenerate chromium-bidi's protocol types"

	# The native TypeScript compiler must be copied, not symlinked: tsc loads
	# lib*.d.ts from the directory of its symlink-resolved executable, and has
	# to use the in-tree ones next to it (Chromium patches lib.dom.d.ts, see
	# third_party/typescript/README.chromium; and tools/typescript/ts_library.py
	# rejects .d.ts files from outside the source tree).
	local tsgo_src="${BROOT}/usr/lib/typescript/${TSGO_VER}/tsc"
	[[ -f ${tsgo_src} ]] || die "Expected to find ${tsgo_src}, but it does not exist."
	einfo "Copying ${tsgo_src} ..."
	# Remove what is left first: cp would follow a symlink put there instead of the
	# deleted prebuilt binary (e.g. one pointing at /dev/null/INVALID).
	rm -f "${tsgo_dir}/tsc" || die "Failed to remove ${tsgo_dir}/tsc"
	cp "${tsgo_src}" "${tsgo_dir}/tsc" || die "Failed to copy ${tsgo_src}"
	found=$("${tsgo_dir}/tsc" --version) || die "Failed to run ${tsgo_dir}/tsc"
	if [[ "${found}" != "Version ${TSGO_VER}" ]]; then
		die "Unexpected ${tsgo_dir}/tsc --version: ${found}"
	fi

	# Rollup: everything in @rollup/wasm-node's dist/ is generated (the CLI and library
	# bundles, and the WebAssembly parser deleted above). The build only runs dist/bin/rollup;
	# use dev-util/rollup's, built from the same sources (TypeScript, the npm packages its
	# build bundles in, and the parser's Rust). The WebUI bundles are byte-identical.
	rollup_dir="${S}/third_party/node/node_modules/@rollup/wasm-node"
	local rollup_cli="${BROOT}/usr/lib/rollup/${ROLLUP_VER}/rollup"
	[[ -f ${rollup_cli} ]] || die "Expected to find ${rollup_cli}, but it does not exist."
	einfo "Symlinking ${rollup_cli} ..."
	rm -r "${rollup_dir}/dist" || die "Failed to remove ${rollup_dir}/dist"
	mkdir -p "${rollup_dir}/dist/bin" || die
	ln -s "${rollup_cli}" "${rollup_dir}/dist/bin/rollup" || die "Failed to symlink ${rollup_cli}"

	# DevTools' TypeScript 6 (only its JavaScript API, lib/typescript.js, is used).
	local devtools_ts="${BROOT}/usr/lib/typescript/${DEVTOOLS_TS_VER}/lib/typescript.js"
	[[ -f ${devtools_ts} ]] || die "Expected to find ${devtools_ts}, but it does not exist."
	einfo "Symlinking ${devtools_ts} ..."
	rm -f "${S}/third_party/devtools-frontend/src/node_modules/typescript/lib/typescript.js" || die
	ln -s "${devtools_ts}" "${S}/third_party/devtools-frontend/src/node_modules/typescript/lib/typescript.js" ||
		die "Failed to symlink ${devtools_ts}"

	# DevTools checks in files generated from Blink's and V8's definitions: front_end/generated/
	# (the protocol, ARIA, CSS and deprecation data) and models/javascript_metadata/
	# NativeFunctions.ts (from Blink's Web IDL). Regenerate them with DevTools' own scripts (the
	# first gives byte-identical files; NativeFunctions.ts differs: 156's IDL, which DevTools'
	# copy lags behind, and the order of its lists, made deterministic by
	# chromium-156-devtools-natives-sorted.patch). Not regenerated: panels/timeline/components/MetricCompareStrings.ts, "auto-
	# generated" by scripts/generate_metric_compare_strings.js, which is stale (the file has been
	# edited by hand since).
	einfo "Regenerating DevTools' generated files ..."
	pushd third_party/devtools-frontend/src >/dev/null || die
	"${EPYTHON}" scripts/deps/generate_protocol_resources.py --node-path "$(type -P node)" ||
		die "Failed to regenerate DevTools' protocol resources"
	# NativeFunctions.ts also needs TypeScript's lib*.d.ts (dev-lang/typescript's) and webidl2's
	# sources (lib/; its dist/ bundle isn't used)
	rm -r node_modules/webidl2/dist || die
	local natives_ts="${T}/javascript-natives"
	mkdir -p "${natives_ts}/node_modules" || die
	ln -s "${BROOT}/usr/lib/typescript/${DEVTOOLS_TS_VER}" "${natives_ts}/node_modules/typescript" || die
	node scripts/javascript_natives/index.js "${S}" "${natives_ts}" ||
		die "Failed to regenerate NativeFunctions.ts"
	popd >/dev/null || die

	# Other generated files of npm packages (terser's library bundle, chromium-bidi's rollup
	# plugins, ...): dev-util/chromium-node-modules builds them from their sources, as
	# self-contained bundles, at the paths of the files they replace. The packages they include
	# are deleted above (files/chromium-${PV%%.*}-node-modules.txt).
	local cnm_dir="${BROOT}/usr/lib/chromium-node-modules/${PV%%.*}" cnm_pkg cnm_ver cnm_file
	[[ -f ${cnm_dir}/VERSIONS ]] || die "Expected to find ${cnm_dir}/VERSIONS, but it does not exist."
	local cnm_tree="${cnm_dir}/tree"
	while read -r cnm_pkg cnm_ver; do
		# package.json's version, or for a vendored directory without one, README.chromium's
		found=$("${EPYTHON}" -c '
import json, os, re, sys
d = sys.argv[1]
version = None
if os.path.exists(d + "/package.json"):
    version = json.load(open(d + "/package.json")).get("version")
if version is None:
    version = re.search(r"^Version: (\S+)$", open(d + "/README.chromium").read(), re.M).group(1)
print(version)
' "${S}/${cnm_pkg}") || die "Failed to read the version of ${cnm_pkg}"
		[[ ${found} == "${cnm_ver}" ]] ||
			die "Version mismatch in ${cnm_pkg}: dev-util/chromium-node-modules has ${cnm_ver}, found ${found}"
	done < "${cnm_dir}/VERSIONS" || die
	einfo "Replacing generated npm package files with dev-util/chromium-node-modules' ..."
	while IFS= read -r -d '' cnm_file; do
		# Every file replaces one, except new chunks of code-split builds.
		[[ -f ${S}/${cnm_file} || ${cnm_file##*/} == chunk-* ]] ||
			die "${cnm_file} not found in the source tree"
		# Remove first: cp would follow a symlink left in its place.
		rm -f "${S}/${cnm_file}" || die
		cp "${cnm_tree}/${cnm_file}" "${S}/${cnm_file}" || die "Failed to copy ${cnm_file}"
	done < <(cd "${cnm_tree}" && find . -type f -printf '%P\0' || die)
	# DevTools' puppeteer-core (package/lib: the modules DevTools uses, of puppeteer's lib/)
	local devtools_puppeteer="${S}/third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib"
	while IFS= read -r -d '' cnm_file; do
		[[ -f ${cnm_dir}/build/devtools-puppeteer/lib/${cnm_file} ]] ||
			die "puppeteer's ${cnm_file} not built by dev-util/chromium-node-modules"
		cp "${cnm_dir}/build/devtools-puppeteer/lib/${cnm_file}" "${devtools_puppeteer}/${cnm_file}" || die
	done < <(cd "${devtools_puppeteer}" && find . -name '*.js' -printf '%P\0' || die)
	# Chromium patches some npm packages (third_party/node/patches; the tree has them applied).
	# Of the files replaced above, that is only lit-html.js: apply its patch again.
	pushd "${S}/third_party/node" >/dev/null || die
	eapply "${S}/third_party/node/patches/lit_html.patch"
	popd >/dev/null || die

	# Polymer: third_party/polymer/v3_0's reproduce.sh and minify_polymer.sh generate
	# polymer_bundled.min.js from @polymer/polymer and @webcomponents/shadycss (npm's files are
	# their git sources). Do their steps for Polymer, from the git sources, with the rollup and
	# terser above; the result is byte-identical. (The iron-* elements in components-chromium
	# are their git sources, with the same import rewrites and patches.)
	local polymer_dir="${S}/third_party/polymer/v3_0"
	local polymer_build="${WORKDIR}/polymer-build"
	mkdir -p "${polymer_build}/components-chromium" || die
	cp -a "${WORKDIR}/polymer-${POLYMER_VER}" "${polymer_build}/components-chromium/polymer" || die
	cp -a "${WORKDIR}/shadycss-${SHADYCSS_COMMIT}" "${polymer_build}/components-chromium/shadycss" || die
	pushd "${polymer_build}" >/dev/null || die
	# reproduce.sh
	find components-chromium/ -mindepth 2 -maxdepth 2 -name '*.js' -exec sed -i 's/@polymer\//..\//g' {} + || die
	find components-chromium/ -mindepth 3 -maxdepth 3 -name '*.js' -exec sed -i 's/@polymer\//..\/..\//g' {} + || die
	find components-chromium/polymer/ -mindepth 3 -maxdepth 3 -name '*.js' \
		-exec sed -i 's/@webcomponents\//..\/..\/..\//g' {} + || die
	# (chromium.patch also patches an element, which isn't here: only its Polymer part)
	"${EPYTHON}" -c '
import sys
out, cur, keep = [], [], False
for line in open(sys.argv[1]):
    if line.startswith("diff ") or (line.startswith("--- ") and not (cur and cur[-1].startswith("diff "))):
        if keep: out += cur
        cur, keep = [], False
    cur.append(line)
    keep = keep or (line.startswith("+++ ") and "components-chromium/polymer/" in line)
if keep: out += cur
sys.stdout.write("".join(out))' "${polymer_dir}/chromium.patch" > chromium-polymer.patch || die
	eapply chromium-polymer.patch
	# minify_polymer.sh and minify_polymer.py
	eapply "${polymer_dir}/polymer.patch"
	local f
	for f in $(grep -rl "window\['Shady\(DOM\|CSS\)'\]" components-chromium/polymer components-chromium/shadycss); do
		sed -i "s/window\['ShadyDOM'\]/window.ShadyDOM/g; s/window\['ShadyCSS'\]/window.ShadyCSS/g" "${f}" || die
	done
	cp "${polymer_dir}/polymer.js" components-chromium/polymer/ || die
	einfo "Building Polymer's bundle from source ..."
	node "${S}/third_party/node/node_modules/@rollup/wasm-node/dist/bin/rollup" --silent --format esm \
		--input components-chromium/polymer/polymer.js --file polymer_bundled.js || die "rollup failed"
	node "${S}/third_party/node/node_modules/terser/bin/terser" polymer_bundled.js --compress --mangle \
		--module --comments false --define window.HTMLImports=false --define window.ShadyCSS=false \
		--define window.ShadyDOM=false --define window.Polymer.legacyOptimizations=false \
		--output polymer_bundled.min.js || die "terser failed"
	popd >/dev/null || die
	cp "${polymer_build}/polymer_bundled.min.js" "${polymer_dir}/components-chromium/polymer/" ||
		die "Failed to copy polymer_bundled.min.js"

	# DevTools' lit (front_end/third_party/lit/lib/*.js): what its rebuild.sh does (tsc of
	# src/*.ts, then its rollup.config.mjs, whose .d.ts outputs are kept as they are), with the
	# lit packages dev-util/chromium-node-modules built and the rollup, @rollup/plugin-node-resolve
	# and terser above.
	local devtools_lit="${S}/third_party/devtools-frontend/src/front_end/third_party/lit"
	local cnm_lit="${cnm_dir}/build/devtools-lit/node_modules"
	found=$("${EPYTHON}" -c 'import json, sys; print(json.load(open(sys.argv[1]))["dependencies"]["lit"])' \
		"${devtools_lit}/package.json") || die "Failed to read DevTools' lit version"
	local cnm_lit_ver
	cnm_lit_ver=$("${EPYTHON}" -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' \
		"${cnm_lit}/lit/package.json") || die
	[[ ${found} == "${cnm_lit_ver}" ]] ||
		die "DevTools' lit is ${found}, dev-util/chromium-node-modules has ${cnm_lit_ver}"
	local lit_build="${WORKDIR}/devtools-lit"
	mkdir -p "${lit_build}/node_modules/@rollup/plugin-terser" "${lit_build}/node_modules/rollup-plugin-dts" || die
	cp -r "${devtools_lit}/src" "${devtools_lit}/rollup.config.mjs" "${lit_build}/" || die
	cp -r "${cnm_lit}/." "${lit_build}/node_modules/" || die
	ln -s "${S}/third_party/chromium-bidi/node_modules/@rollup/plugin-node-resolve" \
		"${lit_build}/node_modules/@rollup/plugin-node-resolve" || die
	ln -s "${S}/third_party/node/node_modules/terser" "${lit_build}/node_modules/terser" || die
	cp "${FILESDIR}/chromium-rollup-plugin-terser.mjs" "${lit_build}/node_modules/@rollup/plugin-terser/index.mjs" || die
	echo '{"name": "@rollup/plugin-terser", "exports": "./index.mjs"}' \
		> "${lit_build}/node_modules/@rollup/plugin-terser/package.json" || die
	echo 'export default () => ({ name: "dts" });' > "${lit_build}/node_modules/rollup-plugin-dts/index.mjs" || die
	echo '{"name": "rollup-plugin-dts", "exports": "./index.mjs"}' \
		> "${lit_build}/node_modules/rollup-plugin-dts/package.json" || die
	echo 'import c from "./rollup.config.mjs"; export default c.filter(e => !e.input.endsWith(".d.ts"));' \
		> "${lit_build}/js.config.mjs" || die
	pushd "${lit_build}" >/dev/null || die
	einfo "Building DevTools' lit bundle from source ..."
	# (--noCheck: the lit packages above come without type declarations)
	"${tsgo_dir}/tsc" --ignoreConfig --skipLibCheck --noCheck -d -t esnext -m esnext --moduleResolution bundler \
		src/*.ts ||
		die "tsc failed"
	node "${S}/third_party/node/node_modules/@rollup/wasm-node/dist/bin/rollup" -c js.config.mjs --silent ||
		die "rollup failed"
	popd >/dev/null || die
	for f in "${lit_build}"/lib/*.js; do
		[[ -f ${devtools_lit}/lib/${f##*/} ]] || die "Unexpected DevTools lit output ${f##*/}"
		cp "${f}" "${f}.map" "${devtools_lit}/lib/" || die
	done

	# DevTools' codemirror.next (codemirror.next.js, chunk/*.js): what its rebuild.sh does (tsc of
	# bundle.ts, then its rollup.config.mjs; the .d.ts output is kept), with the packages
	# dev-util/chromium-node-modules built from source and the tools above. (Of chunk/, css.js,
	# html.js and javascript.js are stale: nothing uses them.)
	local devtools_cm="${S}/third_party/devtools-frontend/src/front_end/third_party/codemirror.next"
	local cm_build="${WORKDIR}/devtools-codemirror"
	mkdir -p "${cm_build}/node_modules/@rollup/plugin-terser" "${cm_build}/node_modules/rollup-plugin-dts" || die
	cp "${devtools_cm}/bundle.ts" "${devtools_cm}/rollup.config.mjs" "${cm_build}/" || die
	cp -r "${cnm_dir}/build/devtools-codemirror/node_modules/." "${cm_build}/node_modules/" || die
	ln -s "${S}/third_party/chromium-bidi/node_modules/@rollup/plugin-node-resolve" \
		"${cm_build}/node_modules/@rollup/plugin-node-resolve" || die
	ln -s "${S}/third_party/node/node_modules/terser" "${cm_build}/node_modules/terser" || die
	cp "${FILESDIR}/chromium-rollup-plugin-terser.mjs" "${cm_build}/node_modules/@rollup/plugin-terser/index.mjs" || die
	echo '{"name": "@rollup/plugin-terser", "exports": "./index.mjs"}' \
		> "${cm_build}/node_modules/@rollup/plugin-terser/package.json" || die
	echo 'export default () => ({ name: "dts" });' > "${cm_build}/node_modules/rollup-plugin-dts/index.mjs" || die
	echo '{"name": "rollup-plugin-dts", "exports": "./index.mjs"}' \
		> "${cm_build}/node_modules/rollup-plugin-dts/package.json" || die
	echo 'import c from "./rollup.config.mjs"; export default c.filter(e => !e.input.endsWith(".d.ts"));' \
		> "${cm_build}/js.config.mjs" || die
	pushd "${cm_build}" >/dev/null || die
	einfo "Building DevTools' codemirror.next bundle from source ..."
	# (--noCheck: TypeScript 6 is stricter than the packages' own compiler)
	"${BROOT}/usr/bin/tsc-${DEVTOOLS_TS_VER}" -t esnext -m esnext --moduleResolution bundler --ignoreConfig \
		--skipLibCheck --noCheck bundle.ts || die "tsc failed for codemirror.next"
	node "${S}/third_party/node/node_modules/@rollup/wasm-node/dist/bin/rollup" -c js.config.mjs \
		> rollup.log 2>&1 || die "rollup failed for codemirror.next: $(<rollup.log)"
	# every import must be bundled
	grep -q 'Unresolved dependencies' rollup.log && die "codemirror.next: $(<rollup.log)"
	popd >/dev/null || die
	local cm_rel
	for f in "${cm_build}"/codemirror.next.js "${cm_build}"/chunk/*.js; do
		cm_rel=${f#"${cm_build}"/}
		[[ -f ${devtools_cm}/${cm_rel} ]] || die "Unexpected codemirror.next output ${cm_rel}"
		cp "${f}" "${devtools_cm}/${cm_rel}" || die
		cp "${f}.map" "${devtools_cm}/${cm_rel}.map" || die
	done

	# DevTools' web-vitals (front_end/third_party/web-vitals): package/src is web-vitals' source
	# with DevTools' patches; compile it as its rebuild.sh does.
	local web_vitals="${S}/third_party/devtools-frontend/src/front_end/third_party/web-vitals/package"
	rm -r "${web_vitals}/dist/modules" || die
	"${tsgo_dir}/tsc" --ignoreConfig --skipLibCheck -d -t esnext -m esnext --moduleResolution bundler --strict \
		--outDir "${web_vitals}/dist/modules/" "${web_vitals}"/src/*/*.ts "${web_vitals}/src/index.ts" ||
		die "tsc failed for web-vitals"

	# DevTools' third-party-web: its rebuild.sh's bundle of the package (hand-written lib/, data)
	pushd "${S}/third_party/devtools-frontend/src/front_end/third_party/third-party-web" >/dev/null || die
	"${BROOT}/usr/bin/esbuild-${ESBUILD_VER}" --bundle package/nostats-subset.js --format=esm --outdir=lib \
		--log-level=warning || die "esbuild failed for third-party-web"
	popd >/dev/null || die

	# ClientVariations.js (DevTools' copy of components/variations/proto/devtools/client_variations.js,
	# Chromium's X-Client-Data header parser): generated by update_client_variations.py from the
	# TypeScript ts-proto makes of client_variations.proto. Generate it the same way, with the
	# protoc wrapper (with the system protoc), the tools above, and (for its tsc step) the native
	# TypeScript compiler.
	local cv_tmp="${S}/.gentoo-client-variations"
	mkdir -p "${cv_tmp}" || die
	"${EPYTHON}" "${S}/tools/protoc_wrapper/protoc_wrapper.py" client_variations.proto \
		--protoc "${BROOT}/usr/bin/protoc" --proto-in-dir "${S}/components/variations/proto" \
		--ts-out-dir "${cv_tmp}" --protoc-gen-ts "${S}/tools/protoc_wrapper/protoc-gen-ts_proto.py" \
		--import-dir="${S}/third_party/protobuf/src" || die "protoc failed for client_variations.proto"
	"${EPYTHON}" - "${S}" "${tsgo_dir}/tsc" "${cv_tmp}/client_variations.ts" <<-'EOF' || die "Failed to generate ClientVariations.js"
		import os, subprocess, sys
		src, tsc, proto_ts = sys.argv[1:]
		devtools = os.path.join(src, "components/variations/proto/devtools")
		sys.path.insert(0, devtools)
		import update_client_variations as ucv
		run_node = ucv.node.RunNode
		def run(cmd, *args, **kwargs):
		    if cmd[0] == "TSC":
		        return subprocess.run([tsc, "--noCheck"] + cmd[1:], check=True)
		    return run_node(cmd, *args, **kwargs)
		ucv.node.RunNode = run
		ucv.node_modules.PathToTypescript = lambda: "TSC"
		out = os.path.join(devtools, "client_variations.js")
		ucv.generate_bundle(os.path.join(devtools, "client_variations_uncompiled.ts"), proto_ts, out)
	EOF
	cp "${S}/components/variations/proto/devtools/client_variations.js" \
		"${S}/third_party/devtools-frontend/src/front_end/third_party/chromium/client-variations/ClientVariations.js" || die
	rm -r "${cv_tmp}" || die

	# chromium-bidi bundles its BiDi mapper (used for browser automation, e.g. chromedriver)
	# with its own copy of rollup ${ROLLUP_BIDI_VER}. Use the one above instead: the mapper
	# then only differs by a little more retained dead code (unused enum entries, pure
	# expressions) and number formatting (-32e3 vs -32000), so one dev-util/rollup suffices.
	local bidi_rollup_dir="${S}/third_party/chromium-bidi/node_modules/@rollup/wasm-node"
	rm -r "${bidi_rollup_dir}" || die "Failed to remove ${bidi_rollup_dir}"
	ln -s ../../../node/node_modules/@rollup/wasm-node "${bidi_rollup_dir}" ||
		die "Failed to symlink ${bidi_rollup_dir}"

	einfo "Checking that no prebuilt binaries are left in the source tree ..."
	binary_allowlist+=(
		# Copied from dev-lang/typescript above
		third_party/typescript/linux-amd64/src/lib/tsc
	)
	"${EPYTHON}" "${FILESDIR}/chromium-binary-audit.py" "${binary_allowlist[@]/#/--allow=}" "${S}" ||
		die "Prebuilt binaries found in the source tree, see above"

	# adjust python interpreter version
	sed -i -e "s|\(^script_executable = \).*|\1\"${EPYTHON}\"|g" .gn || die

	# Use the system copy of hwdata's usb.ids
	sed 's|//third_party/usb_ids/src/usb.ids|/usr/share/hwdata/usb.ids|g' \
		-i services/device/public/cpp/usb/BUILD.gn || die "Failed to set system usb.ids path"

	# remove_bundled_libraries.py walks the source tree and looks for paths containing the substring 'third_party'
	# whitelist matches use the right-most matching path component, so we need to whitelist from that point down.
	local keeplibs=(
		base/third_party/cityhash
		base/third_party/double_conversion
		base/third_party/icu
		base/third_party/nspr
		base/third_party/superfasthash
		base/third_party/symbolize
		base/third_party/xdg_user_dirs
		buildtools/third_party/libc++
		buildtools/third_party/libc++abi
		net/third_party/mozilla_security_manager
		net/third_party/quic
		net/third_party/uri_template
		third_party/abseil-cpp
		third_party/angle
		third_party/angle/src/common/third_party/xxhash
		third_party/angle/src/third_party/ceval
		third_party/angle/src/third_party/libXNVCtrl
		third_party/angle/src/third_party/volk
		third_party/anonymous_tokens
		third_party/apple_apsl
		third_party/axe-core
		third_party/blink
		third_party/boringssl
		third_party/boringssl/src/third_party/fiat
		third_party/breakpad
		third_party/breakpad/breakpad/src/third_party/curl
		third_party/brotli
		third_party/catapult
		third_party/catapult/common/py_vulcanize/third_party/rcssmin
		third_party/catapult/common/py_vulcanize/third_party/rjsmin
		third_party/catapult/third_party/beautifulsoup4-4.9.3
		third_party/catapult/third_party/html5lib-1.1
		third_party/catapult/third_party/polymer
		third_party/catapult/third_party/six
		third_party/catapult/third_party/typ
		third_party/catapult/tracing/third_party/d3
		third_party/catapult/tracing/third_party/gl-matrix
		third_party/catapult/tracing/third_party/jpeg-js
		third_party/catapult/tracing/third_party/jszip
		third_party/catapult/tracing/third_party/mannwhitneyu
		third_party/catapult/tracing/third_party/oboe
		third_party/catapult/tracing/third_party/pako
		third_party/ced
		third_party/chromium-bidi
		third_party/cld_3
		third_party/closure_compiler
		third_party/compiler-rt # Since M137 atomic is required; we could probably unbundle this as a target of opportunity.
		third_party/content_analysis_sdk
		third_party/cpuinfo
		third_party/crabbyavif
		third_party/crashpad
		third_party/crashpad/crashpad/third_party/lss
		third_party/crashpad/crashpad/third_party/zlib
		third_party/crc32c
		third_party/cros_system_api
		third_party/d3
		third_party/dav1d
		third_party/dawn
		third_party/dawn/third_party/gn/webgpu-cts
		third_party/dawn/third_party/OpenGL-Registry
		third_party/dawn/third_party/renderdoc
		third_party/dawn/third_party/webgpu-headers
		third_party/depot_tools
		third_party/devscripts
		third_party/devtools-frontend
		third_party/devtools-frontend/src/front_end/third_party/acorn
		third_party/devtools-frontend/src/front_end/third_party/additional_readme_paths.json
		third_party/devtools-frontend/src/front_end/third_party/axe-core
		third_party/devtools-frontend/src/front_end/third_party/chromium
		third_party/devtools-frontend/src/front_end/third_party/codemirror
		third_party/devtools-frontend/src/front_end/third_party/csp_evaluator
		third_party/devtools-frontend/src/front_end/third_party/diff
		third_party/devtools-frontend/src/front_end/third_party/i18n
		third_party/devtools-frontend/src/front_end/third_party/intl-messageformat
		third_party/devtools-frontend/src/front_end/third_party/json5
		third_party/devtools-frontend/src/front_end/third_party/legacy-javascript
		third_party/devtools-frontend/src/front_end/third_party/lighthouse
		third_party/devtools-frontend/src/front_end/third_party/lit
		third_party/devtools-frontend/src/front_end/third_party/marked
		third_party/devtools-frontend/src/front_end/third_party/puppeteer
		third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party/mitt
		third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party/parsel-js
		third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party/rxjs
		third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party/urlpattern-polyfill
		third_party/devtools-frontend/src/front_end/third_party/source-map-scopes-codec
		third_party/devtools-frontend/src/front_end/third_party/third-party-web
		third_party/devtools-frontend/src/front_end/third_party/vscode.web-custom-data
		third_party/devtools-frontend/src/front_end/third_party/wasmparser
		third_party/devtools-frontend/src/front_end/third_party/web-vitals
		third_party/devtools-frontend/src/third_party
		third_party/dom_distiller_js
		third_party/dragonbox
		third_party/eigen3
		third_party/emoji-segmenter
		third_party/farmhash
		third_party/fast_float
		third_party/fdlibm
		third_party/federated_compute/chromium/fcp/confidentialcompute
		third_party/federated_compute/chromium/fcp/protos
		third_party/federated_compute/chromium/fcp/secagg
		third_party/federated_compute/chromium/fcp/client
		third_party/federated_compute/src/fcp/base
		third_party/federated_compute/src/fcp/confidentialcompute
		third_party/federated_compute/src/fcp/protos
		third_party/federated_compute/src/fcp/client
		third_party/federated_compute/src/fcp/secagg
		third_party/federated_compute/third_party/googleapis/src/google
		third_party/federated_compute/third_party/tensorflow-federated
		third_party/federated_compute/third_party/protodatastore-cpp
		third_party/ffmpeg
		third_party/fft2d
		third_party/flatbuffers
		third_party/fp16
		third_party/freetype
		third_party/fusejs
		third_party/fxdiv
		third_party/gemmlowp
		third_party/google_input_tools
		third_party/google_input_tools/third_party/closure_library
		third_party/google_input_tools/third_party/closure_library/third_party/closure
		third_party/googletest
		third_party/gperf # We symlink system gperf, but this will purge the symlink since we tidy up afterwards.
		third_party/highway
		third_party/hunspell
		third_party/iamf_tools
		third_party/ink/src/ink/brush
		third_party/ink/src/ink/color
		third_party/ink/src/ink/geometry
		third_party/ink/src/ink/rendering
		third_party/ink/src/ink/rendering/skia/common_internal
		third_party/ink/src/ink/rendering/skia/native
		third_party/ink/src/ink/rendering/skia/native/internal
		third_party/ink/src/ink/strokes
		third_party/ink/src/ink/types
		third_party/inspector_protocol
		third_party/ipcz
		third_party/jinja2
		third_party/jsoncpp
		third_party/khronos
		third_party/lens_server_proto
		third_party/leveldatabase
		third_party/libaddressinput
		third_party/libaom
		third_party/libaom/source/libaom/third_party/fastfeat
		third_party/libaom/source/libaom/third_party/vector
		third_party/libaom/source/libaom/third_party/x86inc
		third_party/libc++
		third_party/libdrm
		third_party/libgav1
		third_party/libjingle
		third_party/libpfm4
		third_party/libphonenumber
		third_party/libpng
		third_party/libsecret
		third_party/libsrtp
		third_party/libsync
		third_party/libtess2/libtess2
		third_party/libtess2/src/Include
		third_party/libtess2/src/Source
		third_party/liburlpattern
		third_party/libva_protected_content
		third_party/libvpx
		third_party/libvpx/source/libvpx/third_party/x86inc
		third_party/libwebm
		third_party/libx11
		third_party/libxcb-keysyms
		third_party/libxml/chromium
		third_party/libyuv
		third_party/libzip
		third_party/lit
		third_party/llvm-libc
		third_party/llvm-libc/src/shared/
		third_party/lottie
		third_party/lss
		third_party/lzma_sdk
		third_party/mako
		third_party/markupsafe
		third_party/material_color_utilities
		third_party/metrics_proto
		third_party/minigbm
		third_party/ml_dtypes
		third_party/modp_b64
		third_party/nasm
		third_party/nearby
		third_party/neon_2_sse
		third_party/node
		third_party/oak/chromium/proto
		third_party/oak/chromium/proto/attestation
		third_party/omnibox_proto
		third_party/one_euro_filter
		third_party/openscreen
		third_party/openscreen/src/third_party/
		third_party/openscreen/src/third_party/tinycbor/src/src
		third_party/openxr
		third_party/opus
		third_party/ots
		third_party/pdfium
		third_party/pdfium/third_party/agg23
		third_party/pdfium/third_party/bigint
		third_party/pdfium/third_party/freetype
		third_party/pdfium/third_party/lcms
		third_party/pdfium/third_party/libopenjpeg
		third_party/pdfium/third_party/libtiff
		third_party/perfetto
		third_party/perfetto/protos/third_party/android
		third_party/perfetto/protos/third_party/chromium
		third_party/perfetto/protos/third_party/pprof
		third_party/perfetto/protos/third_party/primes
		third_party/perfetto/protos/third_party/simpleperf
		third_party/pffft
		third_party/ply
		third_party/polymer
		third_party/private_membership
		third_party/private-join-and-compute
		third_party/protobuf
		third_party/protobuf/third_party/utf8_range
		third_party/pthreadpool
		third_party/puffin
		third_party/pyjson5
		third_party/pyyaml
		third_party/rapidhash
		third_party/re2
		third_party/readability
		third_party/rnnoise
		third_party/rust
		third_party/ruy
		third_party/s2cellid
		third_party/search_engines_data
		third_party/securemessage
		third_party/selenium-atoms
		third_party/sentencepiece
		third_party/sentencepiece/src/third_party/darts_clone
		third_party/shell-encryption
		third_party/simdutf
		third_party/simplejson
		third_party/six
		third_party/skia
		third_party/skia/include/third_party/vulkan
		third_party/smhasher
		third_party/snappy
		third_party/spirv-headers
		third_party/spirv-tools
		third_party/sqlite
		third_party/swiftshader
		third_party/swiftshader/third_party/astc-encoder
		third_party/swiftshader/third_party/llvm-subzero
		third_party/swiftshader/third_party/marl
		third_party/swiftshader/third_party/SPIRV-Headers/include/spirv
		third_party/swiftshader/third_party/SPIRV-Tools
		third_party/swiftshader/third_party/subzero
		third_party/tensorflow_models
		third_party/tensorflow-text
		third_party/tflite
		third_party/tflite/src/third_party/fft2d
		third_party/tflite/src/third_party/xla/third_party/tsl
		third_party/tflite/src/third_party/xla/xla/tsl/framework
		third_party/tflite/src/third_party/xla/xla/tsl/lib/random
		third_party/tflite/src/third_party/xla/xla/tsl/platform
		third_party/tflite/src/third_party/xla/xla/tsl/protobuf
		third_party/tflite/src/third_party/xla/xla/tsl/util
		third_party/typescript
		third_party/ukey2
		third_party/utf
		third_party/vulkan
		third_party/wayland
		third_party/webdriver
		third_party/webgpu-cts
		third_party/webrtc
		third_party/webrtc/common_audio/third_party/ooura
		third_party/webrtc/common_audio/third_party/spl_sqrt_floor
		third_party/webrtc/modules/third_party/fft
		third_party/webrtc/modules/third_party/g711
		third_party/webrtc/modules/third_party/g722
		third_party/widevine
		third_party/woff2
		third_party/wuffs
		third_party/x11proto
		third_party/xcbproto
		third_party/xnnpack
		third_party/zlib/google
		third_party/zxcvbn-cpp
		url/third_party/mozilla
		v8/third_party/inspector_protocol
		v8/third_party/rapidhash-v8
		v8/third_party/siphash
		v8/third_party/utf8-decoder
		v8/third_party/v8
		v8/third_party/valgrind

		# gyp -> gn leftovers
		third_party/speech-dispatcher
		third_party/usb_ids
	)

	if use rar; then
		keeplibs+=( third_party/unrar )
	fi

	if use test; then
		keeplibs+=(
			third_party/breakpad/breakpad/src/processor
			third_party/fuzztest
			third_party/google_benchmark/src/include/benchmark
			third_party/google_benchmark/src/src
			third_party/test_fonts
			third_party/test_fonts/fontconfig
			third_party/test_fonts/test_fonts
		)
	fi

	# USE=system-*
	if ! use system-harfbuzz; then
		keeplibs+=( third_party/harfbuzz )
	fi

	if ! use system-icu; then
		keeplibs+=( third_party/icu )
	fi

	if ! use system-zstd; then
		keeplibs+=( third_party/zstd )
	fi

	# Arch-specific
	if use arm64 || use ppc64 ; then
		keeplibs+=( third_party/swiftshader/third_party/llvm-10.0 )
	fi
	# we need to generate ppc64 stuff because upstream does not ship it yet
	# it has to be done before unbundling.
	if use ppc64; then
		pushd third_party/libvpx >/dev/null || die
		mkdir -p source/config/linux/ppc64 || die
		# requires git and clang, bug #832803
		# Revert https://chromium.googlesource.com/chromium/src/+/b463d0f40b08b4e896e7f458d89ae58ce2a27165%5E%21/third_party/libvpx/generate_gni.sh
		# and https://chromium.googlesource.com/chromium/src/+/71ebcbce867dd31da5f8b405a28fcb0de0657d91%5E%21/third_party/libvpx/generate_gni.sh
		# since we're not in a git repo
		sed -i -e "s|^update_readme||g; s|clang-format|${EPREFIX}/bin/true|g; /^git -C/d; /git cl/d; /cd \$BASE_DIR\/\$LIBVPX_SRC_DIR/ign format --in-place \$BASE_DIR\/BUILD.gn\ngn format --in-place \$BASE_DIR\/libvpx_srcs.gni" \
			generate_gni.sh || die
		./generate_gni.sh || die
		popd >/dev/null || die

		pushd third_party/ffmpeg >/dev/null || die
		cp libavcodec/ppc/h264dsp.c libavcodec/ppc/h264dsp_ppc.c || die
		cp libavcodec/ppc/h264qpel.c libavcodec/ppc/h264qpel_ppc.c || die
		popd >/dev/null || die
	fi

	# Sanity check keeplibs, on major version bumps it is often necessary to update this list
	# and this enables us to hit them all at once.
	# There are some entries that need to be whitelisted (TODO: Why? The file is understandable, the rest seem odd)
	whitelist_libs=(
		net/third_party/quic
		third_party/devtools-frontend/src/front_end/third_party/additional_readme_paths.json
		third_party/libjingle
		third_party/mesa
		third_party/skia/third_party/vulkan
		third_party/vulkan
	)
	local not_found_libs=()
	for lib in "${keeplibs[@]}"; do
		if [[ ! -d "${lib}" ]] && ! has "${lib}" "${whitelist_libs[@]}"; then
			not_found_libs+=( "${lib}" )
		fi
	done

	if [[ ${#not_found_libs[@]} -gt 0 ]]; then
		eerror "The following \`keeplibs\` directories were not found in the source tree:"
		for lib in "${not_found_libs[@]}"; do
			eerror "  ${lib}"
		done
		die "Please update the ebuild."
	fi

	# Remove most bundled libraries. Some are still needed.
	einfo "Unbundling third-party libraries ..."
	build/linux/unbundle/remove_bundled_libraries.py "${keeplibs[@]}" --do-remove || die

	# Interferes with our bundled clang path; we don't want stripped binaries anyway.
	sed -i -e 's|${clang_base_path}/bin/llvm-strip|/bin/true|g' \
		-e 's|${clang_base_path}/bin/llvm-objcopy|/bin/true|g' \
		build/linux/strip_binary.gni || die
}

chromium_configure() {
	# Calling this here supports resumption via FEATURES=keepwork
	python_setup

	# 974899: sometimes people try to build with a non-Unicode locale and python gets very upset
	python_export_utf8_locale || die "Chromium builds require a UTF-8 locale."

	# Bug 491582.
	export TMPDIR="${WORKDIR}/temp"
	mkdir -p -m 755 "${TMPDIR}" || die

	# https://bugs.gentoo.org/654216
	addpredict /dev/dri/ #nowarn

	# Use system-provided libraries.
	# TODO: freetype -- remove sources (https://bugs.chromium.org/p/pdfium/issues/detail?id=733).
	# TODO: use_system_hunspell (upstream changes needed).
	# TODO: use_system_protobuf (bug #525560).
	# TODO: use_system_sqlite (http://crbug.com/22208).

	# libevent: https://bugs.gentoo.org/593458
	local gn_system_libraries=(
		flac
		fontconfig
		freetype
		# Need harfbuzz_from_pkgconfig target
		#harfbuzz-ng
		libjpeg
		libwebp
		libxml
		libxslt
		openh264
		zlib
	)

	if use system-icu; then
		gn_system_libraries+=( icu )
	fi

	if use system-zstd; then
		gn_system_libraries+=( zstd )
	fi

	build/linux/unbundle/replace_gn_files.py --system-libraries "${gn_system_libraries[@]}" ||
		die "Failed to replace GN files for system libraries"

	# TODO 131: The above call clobbers `enable_freetype = true` in the freetype gni file
	# drop the last line, then append the freetype line and a new curly brace to end the block
	local freetype_gni="build/config/freetype/freetype.gni"
	sed -i -e '$d' ${freetype_gni} || die
	echo "  enable_freetype = true" >> ${freetype_gni} || die
	echo "}" >> ${freetype_gni} || die

	if use !custom-cflags; then
		replace-flags "-Os" "-O2"
		strip-flags
		# Debug info section overflows without component build
		# Prevent linker from running out of address space, bug #471810 .
		filter-flags "-g*"
		# 949123: Several multimedia components explicitly build with specific CFLAGS and
		# use runtime detection to enable optimisations; unfortunately any of our CFLAGS are suffixed
		# to the end of the command line, which causes build failures.
		# Since M150 `skia` will begin breaking for x86_64 due to compilation of `avx512` code paths;
		# we need to filter these for all arches.
		filter-flags "-march*" "-mtune*" "-mcpu*"

	fi

	# We don't use the same clang version as upstream, and with -Werror
	# we need to make sure that we don't get superfluous warnings.
	append-flags -Wno-unknown-warning-option
	if tc-is-cross-compiler; then # can you cross-compile with the bundled toolchain?
			export BUILD_CXXFLAGS+=" -Wno-unknown-warning-option"
			export BUILD_CFLAGS+=" -Wno-unknown-warning-option"
	fi

	# Start building our GN options
	local myconf_gn=() # Tip: strings must be quoted, bools or numbers are fine

	if use !bundled-toolchain; then
		# We already forced the "correct" clang via pkg_setup

		if tc-is-cross-compiler; then
			CC="${CC} -target ${CHOST} --sysroot ${ESYSROOT}"
			CXX="${CXX} -target ${CHOST} --sysroot ${ESYSROOT}"
			BUILD_AR=${AR}
			BUILD_CC=${CC}
			BUILD_CXX=${CXX}
			BUILD_NM=${NM}
		fi

		# Make sure the build system will use the right tools, bug #340795.
		tc-export AR CC CXX NM

		strip-unsupported-flags
		append-ldflags -Wl,--undefined-version # https://bugs.gentoo.org/918897#c32

		myconf_gn+=(
			"is_clang=true"
			"clang_use_chrome_plugins=false"
			"use_clang_modules=false" # M141 enables this for the linux platform by default.
			'custom_toolchain="//build/toolchain/linux/unbundle:default"'
			# From M127 we need to provide a location for libclang and the clang resource dir so that bindgen can find them
			"bindgen_libclang_path=\"$(get_llvm_prefix)/$(get_libdir)\""
			"bindgen_clang_resource_dir=\"${EPREFIX}/usr/lib/clang/${LLVM_SLOT}/include\""
			"bindgen_extra_clang_args=[\"-I${EPREFIX}/usr/lib/clang/${LLVM_SLOT}/include\"]"
			"clang_base_path=\"${EPREFIX}/usr/lib/clang/${LLVM_SLOT}/\""
			"clang_version=\"${LLVM_SLOT}\""
			# M156: V8 parses its headers with libclang at build time (metagen);
			# upstream uses a prebuilt libclang, we use the system one.
			"v8_metagen_libclang_so=\"$(get_llvm_prefix -b)/$(get_libdir)/libclang.so\""
			"v8_metagen_libclang_bindings_dir=\"$(python_get_sitedir)\""
			"v8_metagen_clang_resource_dir=\"${BROOT}/usr/lib/clang/${LLVM_SLOT}\""
			"rust_bindgen_root=\"${EPREFIX}/usr/\""
			"rust_sysroot_absolute=\"$(get_rust_prefix)\""
			"rustc_version=\"${RUST_SLOT}\""
			# Crubit (cpp_api_from_rust); checked in pkg_setup. Upstream formats its
			# generated headers with a bundled clang-format, which we remove.
			"rust_crubit_root=\"${BROOT}/usr/lib/crubit/${RUST_SLOT}\""
			"rust_crubit_clang_format=\"$(get_llvm_prefix -b)/bin/clang-format\""
		)

		# Currently disabled, runtime issues with mold
		#if tc-ld-is-mold; then
		#	myconf_gn+=(
		#		"use_mold=true"
		#		"use_lld=false"
		#		"linker_path=\"${EPREFIX}/usr/bin/mold\""
		#	)
		#else
		myconf_gn+=( "use_lld=true" )
		#fi

		if [[ ${LLVM_SLOT} -lt 23 ]]; then
			# Workaround for -fsanitize-ignore-for-ubsan-feature (added in LLVM 23)
			myconf_gn+=( 'clang_has_ubsan_feature_ignore=false' )
		fi

		if ! tc-is-cross-compiler; then
			myconf_gn+=( 'host_toolchain="//build/toolchain/linux/unbundle:default"' )
		else
			tc-export BUILD_{AR,CC,CXX,NM}
			myconf_gn+=(
				'host_toolchain="//build/toolchain/linux/unbundle:host"'
				'v8_snapshot_toolchain="//build/toolchain/linux/unbundle:host"'
				"host_pkg_config=\"$(tc-getBUILD_PKG_CONFIG)\""
				"pkg_config=\"$(tc-getPKG_CONFIG)\""
			)

			# setup cups-config, build system only uses --libs option
			if use cups; then
				mkdir "${T}/cups-config" || die
				cp "${ESYSROOT}/usr/bin/${CHOST}-cups-config" "${T}/cups-config/cups-config" || die
				export PATH="${PATH}:${T}/cups-config"
			fi

			# Don't inherit PKG_CONFIG_PATH from environment
			local -x PKG_CONFIG_PATH=
		fi

	fi # !bundled-toolchain

	local myarch
	myarch="$(tc-arch)"
	case ${myarch} in
		amd64)
			# Bug 530248, 544702, 546984, 853646.
			use !custom-cflags && filter-flags -mno-mmx -mno-sse2 -mno-ssse3 -mno-sse4.1 \
										-mno-avx -mno-avx2 -mno-fma -mno-fma4 -mno-xop -mno-sse4a
			myconf_gn+=( 'target_cpu="x64"' )
			;;
		arm64)
			myconf_gn+=( 'target_cpu="arm64"' )
			;;
		ppc64)
			myconf_gn+=( 'target_cpu="ppc64"' )
			;;
		*)
			die "Failed to determine target arch, got '${myarch}'."
			;;
	esac

	# Common options

	if use hardened; then
		myconf_gn+=(
			# Zero-initialise stack variables (official builds already do)
			"init_stack_vars=true"
			"init_stack_vars_zero=true"
			# V8's WebAssembly interpreter (DrumBrake), which the 0212 patch's
			# --wasm-jitless needs; without it, sites with JIT disabled get no
			# WebAssembly at all.
			"v8_enable_drumbrake=true"
		)
	fi

	myconf_gn+=(
		# Disable code formating of generated files
		"blink_enable_generated_code_formatting=false"
		# enable DCHECK with USE=debug only, increases chrome binary size by 30%, bug #811138.
		# DCHECK is fatal by default, make it configurable at runtime, #bug 807881.
		"dcheck_always_on=$(usex debug true false)"
		"dcheck_is_configurable=$(usex debug true false)"
		# Chromium builds provided by Linux distros should disable the testing config
		"disable_fieldtrial_testing_config=true"
		# Custom patch: Enable building Chromium as individual channels (e.g. stable, beta, dev) that
		# use different profile directories, desktop entries, etc. This enables slotting the ebuild.
		"enable_channel_branding=true"
		# 131 began laying the groundwork for replacing freetype with
		# "Rust-based Fontations set of libraries plus Skia path rendering"
		# We now need to opt-in
		"enable_freetype=true"
		"enable_hangout_services_extension=$(usex hangouts true false)"
		# Don't need nocompile checks and GN crashes with our config (verify with modern GN)
		"enable_nocompile_tests=false"
		# pseudolocales are only used for testing
		"enable_pseudolocales=false"
		# Chrome Remote Desktop host (never built or installed here). Only stops GN from loading
		# remoting/, whose pkg-config probe made PipeWire a mandatory build dependency since M149;
		# chrome/chromedriver/chrome_sandbox are unchanged (identical ninja commands and inputs).
		"enable_remoting=false"
		# ESLint/Stylelint checks of WebUI sources (chromium-156-webui-lint-arg.patch): they don't
		# change the build output, and their npm packages are deleted in src_prepare.
		"enable_webui_lint=false"
		"enable_widevine=$(usex widevine true false)"
		# Disable fatal linker warnings, bug 506268.
		"fatal_linker_warnings=false"
		# Set up Google API keys, see http://www.chromium.org/developers/how-tos/api-keys
		# Note: these are for Gentoo use ONLY. For your own distribution,
		# please get your own set of keys. Feel free to contact chromium@gentoo.org for more info.
		# note: OAuth2 is patched in; check patchset for details.
		'google_api_key="AIzaSyDEAOvatFo0eTgsV_ZlEzx0ObmepsMzfAc"'
		# Component build isn't generally intended for use by end users. It's mostly useful
		# for development and debugging.
		"is_component_build=false"
		# GN needs explicit config for Debug/Release as opposed to inferring it from build directory.
		"is_debug=false"
		"is_official_build=$(usex official true false)"
		# Enable ozone wayland and/or headless support
		"ozone_auto_platforms=false"
		"ozone_platform_headless=true"
		# Enables building without non-free unRAR licence
		"safe_browsing_use_unrar=$(usex rar true false)"
		"thin_lto_enable_optimizations=${use_lto}"
		"treat_warnings_as_errors=false"
		# Use in-tree libc++ (buildtools/third_party/libc++ and buildtools/third_party/libc++abi)
		# instead of the system C++ library for C++ standard library support.
		# default: true, but let's be explicit (forced since 120 ; USE removed 127).
		"use_custom_libcxx=true"
		# Enable ozone wayland and/or headless support
		"use_ozone=true"
		# The sysroot is the oldest debian image that chromium supports, we don't need it
		"use_sysroot=false"
		# See dependency logic in third_party/BUILD.gn
		"use_system_harfbuzz=$(usex system-harfbuzz true false)"
		"use_thin_lto=${use_lto}"
		# use system go
		"tint_use_system_go=true"
	)

	if use bindist ; then
		myconf_gn+=(
			# If this is set to false Chromium won't be able to load any proprietary codecs
			# even if provided with an ffmpeg capable of h264/aac decoding
			"proprietary_codecs=true"
			'ffmpeg_branding="Chrome"'
			# build ffmpeg as an external component (libffmpeg.so) that we can remove / substitute
			"is_component_ffmpeg=true"
		)
	else
		myconf_gn+=(
			"proprietary_codecs=$(usex proprietary-codecs true false)"
			"ffmpeg_branding=\"$(usex proprietary-codecs Chrome Chromium)\""
		)
	fi

	if use headless; then
		myconf_gn+=(
			"enable_print_preview=false"
			"enable_remoting=false"
			'ozone_platform="headless"'
			"rtc_use_pipewire=false"
			"use_alsa=false"
			"use_cups=false"
			"use_gio=false"
			"use_glib=false"
			"use_gtk=false"
			"use_kerberos=false"
			"use_libpci=false"
			"use_pangocairo=false"
			"use_pulseaudio=false"
			"use_qt5=false"
			"use_qt6=false"
			"use_udev=false"
			"use_vaapi=false"
			"use_xkbcommon=false"
		)
	else
		myconf_gn+=(
			"gtk_version=$(usex gtk4 4 3)"
			# link pulseaudio directly (DT_NEEDED) instead of using dlopen.
			# helps with automated detection of ABI mismatches and prevents silent errors.
			"link_pulseaudio=$(usex pulseaudio true false)"
			"ozone_platform_wayland=$(usex wayland true false)"
			"ozone_platform_x11=$(usex X true false)"
			"ozone_platform=\"$(usex wayland wayland x11)\""
			"rtc_use_pipewire=$(usex screencast true false)"
			# As above - link directly instead of dlopening
			"rtc_link_pipewire=$(usex screencast true false)"
			"use_cups=$(usex cups true false)"
			"use_kerberos=$(usex kerberos true false)"
			"use_pulseaudio=$(usex pulseaudio true false)"
			"use_qt5=false"
			"use_system_libffi=$(usex wayland true false)"
			"use_system_minigbm=true"
			"use_vaapi=$(usex vaapi true false)"
			"use_xkbcommon=true"
		)
		if use qt6; then
			local cbuild_libdir
			cbuild_libdir="$(get_libdir)"
			if tc-is-cross-compiler; then
			# Hack to workaround get_libdir not being able to handle CBUILD, bug #794181
				cbuild_libdir="$($(tc-getBUILD_PKG_CONFIG) --keep-system-libs --libs-only-L libxslt)"
				cbuild_libdir="${cbuild_libdir:2}"
				cbuild_libdir="${cbuild_libdir/% }"
			fi
			myconf_gn+=(
				"use_qt6=true"
				"moc_qt6_path=\"${EPREFIX}/usr/${cbuild_libdir}/qt6/libexec\""
			)
		else
			myconf_gn+=( "use_qt6=false" )
		fi
	fi

	# Explicitly disable ICU data file support for system-icu/headless builds.
	if use system-icu || use headless; then
		myconf_gn+=( "icu_use_data_file=false" )
	fi

	if use official; then
		# Allow building against system libraries in official builds
		sed -i 's/OFFICIAL_BUILD/GOOGLE_CHROME_BUILD/' \
			tools/generate_shim_headers/generate_shim_headers.py || die
		if use !ppc64; then
			myconf_gn+=( "is_cfi=${use_lto}" )
			# CFI also checks C++ casts (bad-cast); upstream only does this on
			# ChromeOS and Android.
			use hardened && myconf_gn+=( "use_cfi_cast=${use_lto}" )
		else
			myconf_gn+=( "is_cfi=false" ) # requires llvm-runtimes/compiler-rt-sanitizers[cfi]
		fi
		# Don't add symbols to build
		myconf_gn+=( "symbol_level=0" )
	fi

	if use pgo; then
		myconf_gn+=( "chrome_pgo_phase=${1}" )
		if [[ "$1" == "2" ]]; then
			myconf_gn+=( "pgo_data_path=${2}" )
		fi
	else
		myconf_gn+=( "chrome_pgo_phase=0" )
	fi

	# Odds and ends

	# Disable external code space for V8 for ppc64. It is disabled for ppc64
	# by default, but cross-compiling on amd64 enables it again.
	if tc-is-cross-compiler && use ppc64; then
		myconf_gn+=( "v8_enable_external_code_space=false" )
	fi

	# Since we build from tarballs, we need to set the channel here so that it can be used in the build.
	export CHROME_VERSION_EXTRA="${SLOT}"

	einfo "Configuring Chromium ..."
	# add a `-v` here if gn `hangs` to see which file it's getting stuck on.
	# GN's toolchain (build/toolchain/linux/unbundle) takes the compilers and flags from the
	# environment, also when ninja regenerates the build files during src_compile (after a
	# BUILD.gn changed). Save what is set up here for chromium_compile, so a regeneration
	# produces the same commands even if the src_compile environment differs.
	export -p | grep -E '^declare -x (AR|CC|CXX|CPP|NM|READELF|CFLAGS|CXXFLAGS|CPPFLAGS|LDFLAGS|BUILD_[A-Z_]+)=' \
		> "${WORKDIR}/gn-toolchain-environment" || die "Failed to save the toolchain environment"

	set -- gn gen --args="${myconf_gn[*]}${EXTRA_GN:+ ${EXTRA_GN}}" out/Release
	echo "$@"
	"$@" || die "Failed to configure Chromium"

	# If ninja already used this build directory (e.g. configure re-run after an interrupted
	# compile), its log records older mtimes for build.ninja(.stamp); ninja >= 1.10 trusts those
	# over the files on disk and would regenerate the build files at the start of src_compile, in
	# src_compile's environment. gn gen only fixes that up itself (ninja -t restat) when given a
	# ninja executable and ninja_required_version >= 1.10, which Chromium's .gn does not declare.
	if [[ -f out/Release/.ninja_log ]]; then
		"${NINJA}" -C out/Release -t restat build.ninja build.ninja.stamp ||
			ewarn "Could not update ninja's log; the next build may regenerate the build files"
	fi
}

src_configure() {
	chromium_configure $(usex pgo 1 0)
}

chromium_compile() {
	# The toolchain environment GN saw in src_configure, for regenerations (see chromium_configure).
	source "${WORKDIR}/gn-toolchain-environment" || die "Failed to restore the toolchain environment"

	# Final link uses lots of file descriptors.
	ulimit -n 2048

	# Calling this here supports resumption via FEATURES=keepwork
	python_setup

	# Don't inherit PYTHONPATH from environment, bug #789021, #812689
	local -x PYTHONPATH=

	# Build mksnapshot and pax-mark it.
	if use pax-kernel; then
		local x
		for x in mksnapshot v8_context_snapshot_generator code_cache_generator; do
			if tc-is-cross-compiler; then
				eninja -C out/Release "host/${x}"
				pax-mark m "out/Release/host/${x}"
			else
				eninja -C out/Release "${x}"
				pax-mark m "out/Release/${x}"
			fi
		done
	fi

	# Even though ninja autodetects number of CPUs, we respect
	# user's options, for debugging with -j 1 or any other reason.
	eninja -C out/Release chrome chromedriver chrome_sandbox $(use test && echo "base_unittests")

	pax-mark m out/Release/chrome

	# This codepath does minimal patching, so we're at the mercy of upstream
	# CFLAGS. This is fine - we're not intending to force this on users
	# and we do a lot of flag 'management' anyway.
	if use bundled-toolchain; then
		QA_FLAGS_IGNORED="
			usr/lib64/chromium-browser/chrome
			usr/lib64/chromium-browser/chrome-sandbox
			usr/lib64/chromium-browser/chromedriver
			usr/lib64/chromium-browser/chrome_crashpad_handler
			usr/lib64/chromium-browser/libEGL.so
			usr/lib64/chromium-browser/libGLESv2.so
			usr/lib64/chromium-browser/libVkICD_mock_icd.so
			usr/lib64/chromium-browser/libVkLayer_khronos_validation.so
			usr/lib64/chromium-browser/libqt6_shim.so
			usr/lib64/chromium-browser/libvk_swiftshader.so
			usr/lib64/chromium-browser/libvulkan.so.1
		"
	fi
}

# This function is called from virtx, and must always return so that Xvfb
# session isn't left running. If we return 1, virtx will call die().
chromium_profile() {
	einfo "Profiling for PGO"

	pushd "${WORKDIR}/chromium-profiler-"* >/dev/null || return 1

	# Remove old profdata in case profiling was interrupted.
	rm -rf "${1}" || return 1

	if ! "${EPYTHON}" ./chromium_profiler.py \
		--chrome-executable "${S}/out/Release/chrome" \
		--chromedriver-executable "${S}/out/Release/chromedriver.unstripped" \
		--add-arg no-sandbox --add-arg disable-dev-shm-usage \
		--profile-output "${1}"; then
		eerror "Profiling failed"
		return 1
	fi

	popd >/dev/null || return 1
}

src_compile() {
	if use pgo; then
		local profdata

		profdata="${WORKDIR}/chromium.profdata"

		if [[ ! -e "${WORKDIR}/.pgo-profiled" ]]; then
			chromium_compile
			virtx chromium_profile "$profdata"

			touch "${WORKDIR}/.pgo-profiled" || die
		fi

		if [[ ! -e "${WORKDIR}/.pgo-phase-2-configured" ]]; then
			# Remove phase 1 output
			rm -r out/Release || die

			chromium_configure 2 "$profdata"

			touch "${WORKDIR}/.pgo-phase-2-configured" || die
		fi

		if [[ ! -e "${WORKDIR}/.pgo-phase-2-compiled" ]]; then
			chromium_compile
			touch "${WORKDIR}/.pgo-phase-2-compiled" || die
		fi
	else
		chromium_compile
	fi

	mv out/Release/chromedriver{.unstripped,} || die

	rm -f out/Release/locales/*.pak.info || die

	# Generate support files (desktop file, manpage, etc.) See: #684550 #706786 #968958
	${EPYTHON} "${FILESDIR}/generate-support-files.py" \
		--installdir "/usr/$(get_libdir)/chromium-browser" \
		--channel "${SLOT}" ||
			die "Failed to generate support files"
}

src_test() {
	# Tests may be flaky with usersandbox, and the test runner executes significantly faster without.
	# If you seem to be excluding too many tests for a particular milestone: comment them out, reboot, and
	# run the tests again. If that doesn't help, try FEATURES="-usersandbox" and send it because obviously the
	# chromium gods are not smiling upon you today. Do some runtime testing, obvs.
	local skip_tests=(
		# Wildcard exclusions (if all tests in a test suite are broken)
		'AlternateTestParams/PartitionAllocDeathTest.RepeatedAllocReturnNullDirect/*'
		'AlternateTestParams/PartitionAllocDeathTest.RepeatedReallocReturnNullDirect/*'
		'AlternateTestParams/PartitionAllocTest.*' # 200+ tests, >= 1 crashes entire test runner with usersandbox.
		'CheckExitCodeAfterSignalHandlerDeathTest.*'
		'CriticalProcessAndThreadSpotChecks/HangWatcherAnyCriticalThreadTests.*'
		'LazyThreadPoolTaskRunnerEnvironmentTest.*' # M142
		'ToolsSanityTest.BadVirtualCall*'
		# Since 151.0.7922.137
		'CheckDeathTest.*'
		'EnumSetDeathTest.*'
		'OptionalRefDeathTest.*'
		'RawRefDeathTest.*'
		'AlternateTestParams/PartitionAllocDeathTest.CheckTriggered*'
		'CallbackHelpersTest.*'
		'SafeRefTest.*'
		'SpanTest.*'
		'WeakValueTableTest.*'
		'PlatformSharedMemoryRegionTest.*'
		'RefCountedOverflowTest.*'
		'SingleThreadTaskRunnerCurrentDefaultHandleTest.*'
		'TestFutureDeathTest.*'
		'WeakPtrDeathTest.*'
		'SafeRefDeathTest.*'
		'LinkedListDeathTest.*'
		'BindDeathTest.*'
		'ReallocProtectedIteratorDeathTest.*'
		'PASpanTest.*'
		'BackupRefPtrTest.*'
		'All/Base64Test.Overflow*'
		'ValuesTest.*'
		'TaskEnvironmentTest.*'
		'CheckedObserverListTest.*'
		'MemoryConsumerRegistryTest.*'
		ProtectedMemoryDeathTest.FailsIfDefinedOutsideOfProtectMemoryRegion
		StructuredSharedMemoryDeathTest.DuplicateRegion
		CheckedContiguousIteratorDeathTest.OutOfBounds
		HeapArrayDeathTest.TakeFirstWithOverSize
		CallbackDeathTest.RunNullCallbackChecks
		ObserverListThreadSafeDeathTest.CrossThreadRemovalRestricted
		SequencedTaskRunnerCurrentDefaultHandleDeathTest.OverrideWithNull
		TestFutureWithoutTaskEnvironmentDeathTest.WaitShouldDcheckWithoutTaskEnvironment
		ScopedThreadPriorityDeathTest.NoRealTime
		ReallocProtectedIteratorDeathTest.StringReallocCrashes
		BarrierCallbackTest.ErrorToCallCallbackWithZeroCallbacks
		BarrierClosureTest.ChecksIfCalledForZeroClosures
		SupportsUserDataTest.ReentrantSetUserDataDuringRemoval
		TimeBase.AddSubInfinities
		LibcppHardeningTest.Assertions
		IDMapTest.RemovedValueHandling
		MultiMemoryConsumerTest.DuplicateInterventionsCheck
		PersistentMemoryAllocatorTest.DelayedAllocationTest
		SequenceCheckerTest.MoveOffSequenceBanned
		ThreadCheckerTest.MoveOffThreadBanned
		TokenType.TokenFromNullUnguessableToken
		ZipTest.CheckForIterationPastTheEnd
		MemoryConsumerTraitsTest.ActiveConsumerWithPassiveTraitsFails
		SingleThreadTaskRunnerMainThreadDefaultHandleTest.Basic

		# requires en-us locale
		SysStrings.SysNativeMBAndWide
		SysStrings.SysNativeMBToWide
		SysStrings.SysWideToNativeMB
		# Specific test cases
		CancelableEventTest.BothCancelFailureAndSucceedOccurUnderContention
		FilePathTest.FromUTF8Unsafe_And_AsUTF8Unsafe
		HistogramTesterTest.PumaTestUniqueSample
		ImmediateCrashTest.ExpectedOpcodeSequence # M150
		PathServiceTest.CheckedGetFailure
		PlatformThreadTest.CanChangeThreadType
		RawPtrTest.SetLookupUsesGetForComparison # M146 ; also broken for alpine in M144.
		RustLogIntegrationTest.CheckAllSeverity
		StackCanary.ChangingStackCanaryCrashesOnReturn
		StackTraceDeathTest.StackDumpSignalHandlerIsMallocFree
		TestLauncherTools.TruncateSnippetFocusedMatchesFatalMessagesTest
		ThreadPoolEnvironmentConfig.CanUseBackgroundPriorityForWorker
		DriveInfoTest.GetFileDriveInfo

	)
	local test_filter="-$(IFS=:; printf '%s' "${skip_tests[*]}")"
	# test-launcher-bot-mode enables parallelism and plain output
	# Check individual tests with --gtest_filter=<test you want> --single-process-tests
	./out/Release/base_unittests --test-launcher-bot-mode \
		--test-launcher-jobs="$(get_makeopts_jobs)" \
		--gtest_filter="${test_filter}" || die "Tests failed!"
}

src_install() {
	local browser_suffix
	if [[ "${SLOT}" != "stable" ]]; then
		browser_suffix="-${SLOT}"
	else
		browser_suffix=""
	fi
	local CHROMIUM_HOME="/usr/$(get_libdir)/chromium-browser${browser_suffix}"
	exeinto "${CHROMIUM_HOME}"
	doexe out/Release/chrome

	newexe out/Release/chrome_sandbox chrome-sandbox
	fperms 4755 "${CHROMIUM_HOME}/chrome-sandbox"

	doexe out/Release/chromedriver
	doexe out/Release/chrome_crashpad_handler

	ozone_auto_session () {
		use X && use wayland && ! use headless && echo true || echo false
	}

	cat <<- EOF > "${D}${CHROMIUM_HOME}/chromium-launcher.sh" || die
		#!/bin/bash
		# Wrapper to launch slotted Chromium via the chromium-common launcher script.
		export CHROME_DESKTOP="chromium-browser${browser_suffix}.desktop"
		export CHROME_EXEC_NAME="chromium-browser${browser_suffix}"
		export CHROME_VERSION_EXTRA="${SLOT}"
		export CHROME_WRAPPER="\$(readlink -f "\$0")"
		export OZONE_AUTO_SESSION=$(ozone_auto_session)

		exec /usr/libexec/chromium/chromium-launcher.sh "\$@"
	EOF

	chmod 755 "${D}${CHROMIUM_HOME}/chromium-launcher.sh" || die

	# It is important that we name the target "chromium-browser",
	# xdg-utils expect it; bug #355517.
	dosym "${CHROMIUM_HOME}/chromium-launcher.sh" /usr/bin/chromium-browser${browser_suffix}
	# keep the old symlink around for consistency
	dosym "${CHROMIUM_HOME}/chromium-launcher.sh" /usr/bin/chromium${browser_suffix}

	dosym "${CHROMIUM_HOME}/chromedriver" /usr/bin/chromedriver${browser_suffix}

	pushd out/Release/locales > /dev/null || die
	chromium_remove_language_paks
	popd > /dev/null || die

	insinto "${CHROMIUM_HOME}"
	doins out/Release/*.bin
	doins out/Release/*.pak

	if use bindist; then
		# We built libffmpeg as a component library, but we can't distribute it
		# with proprietary codec support. Remove it and make a symlink to the requested
		# system library.
		rm -f out/Release/libffmpeg.so \
			|| die "Failed to remove bundled libffmpeg.so (with proprietary codecs)"
		# symlink the libffmpeg.so from either ffmpeg-chromium or ffmpeg[chromium].
		einfo "Creating symlink to libffmpeg.so from $(usex ffmpeg-chromium ffmpeg-chromium ffmpeg[chromium])..."
		dosym ../chromium/libffmpeg.so$(usex ffmpeg-chromium .${PV%%\.*} "") \
			/usr/$(get_libdir)/chromium-browser/libffmpeg.so
	fi

	local test_libs=(
		"libimmediate_crash_test_helper.so"
		"libmalloc_wrapper.so"
		"libtest_shared_library.so"
		"libtest_trace_processor.so"
	)
	if use test; then
		local test_lib
		for test_lib in "${test_libs[@]}"; do
			rm -f "out/Release/${test_lib}" || die "Failed to remove ${test_lib}"
		done
	fi

	(
		shopt -s nullglob
		local files=(out/Release/*.so out/Release/*.so.[0-9])
		[[ ${#files[@]} -gt 0 ]] && doins "${files[@]}"
	)

	if ! use system-icu && ! use headless; then
		doins out/Release/icudtl.dat
	fi

	doins -r out/Release/locales
	doins -r out/Release/MEIPreload

	# Install vk_swiftshader_icd.json; bug #827861
	doins out/Release/vk_swiftshader_icd.json

	if [[ -d out/Release/swiftshader ]]; then
		insinto "${CHROMIUM_HOME}/swiftshader"
		doins out/Release/swiftshader/*.so
	fi

	# Install icons
	local branding size
	for size in 16 24 32 48 64 128 256 ; do
		case ${size} in
			16|32) branding="chrome/app/theme/default_100_percent/chromium" ;;
				*) branding="chrome/app/theme/chromium" ;;
		esac
		newicon -s ${size} "${branding}/product_logo_${size}.png" \
			chromium-browser${browser_suffix}.png
	done

	# Install desktop entry
	domenu out/Release/chromium-browser${browser_suffix}.desktop

	# Install GNOME default application entry (bug #303100).
	insinto /usr/share/gnome-control-center/default-apps
	doins out/Release/chromium-browser${browser_suffix}.xml

	# Install AppStream metadata
	insinto /usr/share/metainfo
	doins out/Release/chromium-browser${browser_suffix}.appdata.xml

	# Install manpage; bug #684550
	doman out/Release/chromium-browser${browser_suffix}.1
	dosym chromium-browser${browser_suffix}.1 /usr/share/man/man1/chromium${browser_suffix}.1

	readme.gentoo_create_doc
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update
	readme.gentoo_print_elog

	if use !headless && [[ -z "${REPLACING_VERSIONS}" ]]; then
		if use vaapi; then
			elog "Hardware-accelerated video decoding configuration:"
			elog
			elog "Chromium supports multiple backends for hardware acceleration. To enable one,"
			elog "   Add to CHROMIUM_FLAGS in /etc/chromium/default:"
			elog
			elog "1. VA-API with OpenGL (recommended for most users):"
			elog "   --enable-features=AcceleratedVideoDecodeLinuxGL"
			elog "   VaapiVideoDecoder may need to be added as well, but try without first."
			elog
			if use wayland; then
				elog "2. Enhanced Wayland/EGL performance:"
				elog "   --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL"
				elog
			fi
			if use X; then
				elog "$(usex wayland "3" "2"). VA-API with Vulkan:"
				elog "   --enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE"
				elog
				if use wayland; then
					elog "   NOTE: Vulkan acceleration requires X11 and will not work under Wayland sessions."
					elog "   Use OpenGL-based acceleration instead when running under Wayland."
					elog
				fi
			fi
			elog "Additional options:"
			elog "  To enable hardware-accelerated encoding (if supported)"
			elog "  add 'AcceleratedVideoEncoder' to your feature list"
			elog "  VaapiIgnoreDriverChecks bypasses driver compatibility checks"
			elog "  (may be needed for newer/unsupported hardware)"
			elog
		else
			elog "This Chromium build was compiled without VA-API support, which provides"
			elog "hardware-accelerated video decoding."
		fi
		if use screencast; then
			elog "Screencast is disabled by default at runtime. Either enable it"
			elog "by navigating to chrome://flags/#enable-webrtc-pipewire-capturer"
			elog "inside Chromium or add --enable-features=WebRTCPipeWireCapturer"
			elog "to CHROMIUM_FLAGS in /etc/chromium/default."
		fi
		if use gtk4; then
			elog "Chromium prefers GTK3 over GTK4 at runtime. To override this"
			elog "behavior you need to pass --gtk-version=4, e.g. by adding it"
			elog "to CHROMIUM_FLAGS in /etc/chromium/default."
		fi
	fi

	if systemd_is_booted && ! [[ -f "/etc/machine-id" ]]; then
		ewarn "The lack of an '/etc/machine-id' file on this system booted with systemd"
		ewarn "indicates that the Gentoo handbook was not followed to completion."
		ewarn ""
		ewarn "Chromium is known to behave unpredictably with this system configuration;"
		ewarn "please complete the configuration of this system before logging any bugs."
	fi

	# Stable slot doesn't change profile directory, and it's vanishingly unlikely that users will downgrade from dev.
	if [[ -n "${REPLACING_VERSIONS}" ]]; then
		local replacing_non_slotted=false
		# there could be more than one PVR
		for version in ${REPLACING_VERSIONS}; do
			if ver_test "${version}" -le "145.0.7632.116"; then
				replacing_non_slotted=true
				break
			fi
		done
		if ${replacing_non_slotted}; then
			ewarn "This version of Chromium has replaced a non-slotted ebuild."
			if [[ ${SLOT} != "stable" ]]; then
				ewarn "This channel has its own profile directory, so your existing profile will not be used."
				ewarn "To use your existing profile, either copy or move it to the new location."
				ewarn "See https://wiki.gentoo.org/wiki/Chromium#Profile_Directories for more information."
				ewarn ""
			fi
			ewarn "Any existing Progressive Web Apps (PWAs) will need to be reinstalled,"
			ewarn "or have the path in the desktop files updated to point to the new wrapper script."
		fi
	fi
}
