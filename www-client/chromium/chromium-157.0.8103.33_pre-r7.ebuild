# Copyright 2009-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# The build is in eclass/chromium-llm.eclass. This ebuild has what is particular to this
# version: upstream's pins (set before inherit: the eclass's global scope uses them), and
# the patches and fixes it applies.

GN_MIN_VER=0.2595
# chromium-tools/get-chromium-toolchain-strings.py (or just use Chromicler)
# Node for M145+ should be 24.12.0 but that's not packaged in Gentoo yet. See #969145
TEST_FONT="9c07d19d9c5ee1ff94f717e6fb17e0c8c354e6f9"
BUNDLED_CLANG_VER="llvmorg-24-init-7747-g62397f8b-67"
BUNDLED_RUST_VER="1edd55dcfcd573872c727fa3e086369a71661ee0-1125"
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
# (ROLLUP_BIDI_VER), which is replaced by the same one (see the eclass's src_prepare).
ROLLUP_VER="4.21.0"
ROLLUP_BIDI_VER="4.63.1"
# dev-util/cddlconv's slot: the version chromium-bidi's checked-in protocol types name.
CDDLCONV_VER="0.2.0"

# LLVM 23 means dev-lang/rust:1.99.0, which also needs a dev-util/crubit:1.99.0
# (Crubit is tied to one Rust build); add 23 together with that.
LLVM_COMPAT=( 22 )
RUST_MIN_VER=1.98.1 # Oldest Rust with a dev-util/crubit build (rustc driver, tied to the Rust build)
# The dev-util/crubit this version needs: <Rust version>_p<CRUBIT_DATE>, the commit date of
# CRUBIT_REVISION in tools/rust/update_rust.py (each Crubit version has its own slot). BDEPEND
# names the one for RUST_MIN_VER, the only Rust that goes with LLVM_COMPAT.
CRUBIT_DATE="20260930"
PPC64_HASH="7aae8a84e327fc2078ce1625c9c70bfda77d626f"
COPIUM_COMMIT="027d15ffdcd1816b7935cee9ea4a4f6bae0bbe60"
# 157.0.8103.33 is a tag without a tarball: built from the 157.0.8103.30 tarball plus
# files/chromium-157.0.8103.30-to-157.0.8103.33.patch (see its header).
CHROMIUM_TARBALL_PV="157.0.8103.30"
# Inputs of ANGLE's code generators that the tarball lacks (files/chromium-angle-regen.py):
# Khronos' registries at ANGLE's (and, for Vulkan, Chromium's) DEPS revisions; perfect-hash,
# the version its built-in symbols generator is written for. Its Vulkan back-end's shaders are
# compiled with the system's glslang (dev-util/glslang; upstream's are from a 2020 glslang).
ANGLE_GL_REGISTRY_COMMIT=9cb90ca4902d588bef3c830fbb1da484893bd5fb
ANGLE_EGL_REGISTRY_COMMIT=7dea2ed79187cd13f76183c4b9100159b9e3e071
ANGLE_CL_DOCS_COMMIT=5b4ca15f0e5a5be87b56b99f652f728e05cab587
VULKAN_HEADERS_COMMIT=c46850864f4661461b0f6cb9922c058ffea4915e
ANGLE_PERFECT_HASH_VER=0.2.1
# Inputs of ICU's generated files (files/chromium-icu-regen.sh): Unicode's release files for
# the Unicode version of the bundled ICU, and the generators from ICU's repository that its
# release (and Chromium's copy) leave out, at the release-78.2 tag.
ICU_UNICODE_VER="17.0.0"
ICU_TOOLS_COMMIT="f1b3db8ecd39d5b3a6eff4d5641b176c7f914dfb"
ICU_TOOLS_FILES="
	py/preparseucd.py
	c/genprops/bidipropsbuilder.cpp c/genprops/casepropsbuilder.cpp c/genprops/corepropsbuilder.cpp
	c/genprops/emojipropsbuilder.cpp c/genprops/genprops.cpp c/genprops/genprops.h
	c/genprops/layoutpropsbuilder.cpp c/genprops/namespropsbuilder.cpp c/genprops/pnamesbuilder.cpp
	c/genuca/collationbasedatabuilder.cpp c/genuca/collationbasedatabuilder.h c/genuca/genuca.cpp
"
# Unicode's plain-text data files come from unicode-org/unicodetools (byte-identical to
# unicode.org's): unicode.org's CDN gives a wrong total size for a range request (that of its
# compressed copy), so that a downloader using ranges (axel) saves a truncated file.
UNICODETOOLS_COMMIT="578f6c0516f5f268292ebda50b51848407a06478"
# The Go modules Dawn's BUILD.gn generator (tools/src/cmd/gen) imports, at the versions in
# its go.mod; served to Go from a local module proxy, checked against Dawn's go.sum.
DAWN_GO_MODULES="
	github.com/mzohreva/gographviz@v0.0.0-20180226085351-533f4a37d9c6
	github.com/tidwall/jsonc@v0.3.3
"
# Vulkan-Docs' header generator script, which Vulkan-Headers (third_party/vulkan-headers) doesn't
# ship (its registry has the rest), at the tag of the headers' version (v1.4.365).
VULKAN_DOCS_COMMIT="8c9361ba8180c1f4164c0bf79de2f6e817770b0d"
# SwiftShader's Vulkan headers (third_party/swiftshader/include): its C headers come from the
# registry of Vulkan-Headers v1.4.355 (the video headers: v1.4.322's), made with Vulkan-Docs'
# genvk.py at the same tags, its C++ headers from Vulkan-Hpp v1.4.355's generator (with the
# tinyxml2 it pins).
SWS_VULKAN_HEADERS_COMMIT="6433e5c70bb9ec995f72d767934acaff8ef11ae3" # v1.4.355
SWS_VULKAN_DOCS_COMMIT="8bd7db8d668381b529b3a2065e65aacdcd244ee2" # v1.4.355
SWS_VIDEO_HEADERS_COMMIT="f69f0433bae0b30598380ef0420b9d2d02dbac4d" # v1.4.322
SWS_VIDEO_DOCS_COMMIT="6ecb205ac29c6c07186c500460c1d9b837993ec2" # v1.4.322
SWS_VULKAN_HPP_COMMIT="f6fa5c494ebd729129a4d674d9b08e5a14bb54a4" # v1.4.355
SWS_TINYXML2_COMMIT="ff61650517cc32d524689366f977716e73d4f924"
# SwiftShader's minimized LLVM for Subzero (third_party/llvm-subzero), on amd64: its TableGen'd
# files come from LLVM trunk r290449 (llvm-mirror's 759dd39, per SwiftShader's history).
SWS_LLVM_COMMIT="759dd39154f0bbf1adc87bf613c95f9564f64aa8"
# The Khronos registries the copies of Khronos' generated headers in third_party/khronos and
# ANGLE's include/ were generated from (their registries' api/ copies at these commits):
# "repository:commit:directory:registry:destination:headers", headers as genheaders.py names
# them, "=path" where the copy is elsewhere under the destination.
KHRONOS_HEADERS="
	OpenGL-Registry:f37a01b810c6b02dd22979352df995555b51ae50:xml:gl.xml:third_party/khronos:../api/GLES3/gl31.h,../api/GLES3/gl32.h
	OpenGL-Registry:accf5ad3cd89ddb5cd6e09b6823bf28bce444c3d:xml:gl.xml:third_party/khronos:../api/GLES3/gl3.h
	EGL-Registry:992aa3914f8fea801b1034c992db389911d9f3c3:api:egl.xml:third_party/khronos:EGL/egl.h
	OpenGL-Registry:9cb90ca4902d588bef3c830fbb1da484893bd5fb:xml:gl.xml:third_party/angle/include:../api/GLES2/gl2.h,../api/GLES2/gl2ext.h,../api/GLES3/gl3.h,../api/GLES3/gl31.h,../api/GLES3/gl32.h
	OpenGL-Registry:08549e96bd581527e38b492e92f6fbdb965b5d77:xml:glx.xml:third_party/angle/include:../api/GL/glxext.h=GLX/glxext.h
	OpenGL-Registry:89acc93eaa6acd97159fb069e66acb92f12d7b87:xml:wgl.xml:third_party/angle/include:../api/GL/wgl.h=WGL/wgl.h
	EGL-Registry:2e25852c8c92fcd67f66844ae780323155a32d7c:api:egl.xml:third_party/angle/include:EGL/egl.h,EGL/eglext.h
"
# OpenXR's code generators, which the OpenXR SDK in third_party/openxr leaves out (they are in
# OpenXR-SDK-Source), at the SDK's release.
OPENXR_VER="1.1.53"

# The generators of pdfium's OpenJPEG and libtiff tables, which pdfium doesn't bundle, at the
# revisions in their README.pdfium (see the eclass's src_prepare).
PDFIUM_OPENJPEG_COMMIT="6c4a29b00211eb0430fa0e5e890f1ce5c80f409f"
PDFIUM_LIBTIFF_COMMIT="d01a94be176f5f6a87f7ee1c0b32e65416aa2b4d"

# The sources of the CDDL chromium-bidi makes its protocol types from (its
# tools/update_bidi_types.py): the specs' sources at the commits current when
# its checked-in types were last regenerated, and the extraction script of the
# WebDriver BiDi spec. Repository, commit, files (see the eclass's src_prepare).
CHROMIUM_BIDI_SPECS="
	w3c/webdriver-bidi:ff4f83dfae2c8c51482acd503c50fb5abfac2cca:index.bs,scripts/cddl/generate.js,scripts/cddl/utils.js
	w3c/permissions:0051a836a92c4f8e37d016f261bbbed5b6312b96:index.html
	WebBluetoothCG/web-bluetooth:2e451c162f6a3f2277f86104223de4630710506e:index.bs
	WICG/nav-speculation:55f0c9565659d4af2fda2cb93060c17a04feb7fd:prefetch.bs
	WICG/ua-client-hints:6cf1025597fe4ee96063f32e94442613a7fa77f9:index.bs
	w3c-fedid/digital-credentials:b31343b4890a39ad3aa6d2bf066db1069458da4f:index.html
"

# The Go module Skia's GL interface generator (tools/ganesh/gl/interface) imports, at the version in
# its go.mod; served to Go from a local module proxy, checked against Skia's go.sum.
SKIA_GO_MODULES="github.com/flynn/json5@v0.0.0-20160717195620-7620272ed633"

# Wuffs' sources at the commit that generated the release/c/wuffs-v0.3.c Chromium vendors
# ("wuffs gen -version=0.3.5", v0.3 branch; third_party/wuffs/src/sync.txt), for its generator.
WUFFS_COMMIT="d1a6f2c3de7e52b8775782028e5a49946a7f9184"
WUFFS_RELEASE_VER="0.3.5"

# simdutf's sources at the release Chromium's amalgamation (third_party/simdutf) was made from
# (7.7.0; its README.chromium names an older revision), for singleheader/amalgamate.py.
SIMDUTF_COMMIT="94fb52ea0219cb37092d8ae294b4702bacf5d8df"

# The Unicode data RE2's table generators read (re2/unicode.py: _UNICODE_DIR), at its version.
RE2_UNICODE_VER="15.1.0"

# The script that generates Jinja's _identifier.py, at the release Chromium bundles (3.1.2).
JINJA_COMMIT="b08cd4bc64bb980df86ed2876978ae5735572280"

# The inputs of bundled HarfBuzz's table generators (src/gen-*.py; used without
# USE=system-harfbuzz): Unicode's data at the version they name, and packTab, which they use.
# Unicode 18.0.0's zipped UCD isn't published (yet): the UCD files they read, one by one.
HB_UNICODE_VER="18.0.0"
HB_UCD_FILES="ArabicShaping Blocks DerivedCoreProperties IndicPositionalCategory IndicSyllabicCategory
	Scripts UnicodeData emoji/emoji-data"
HB_PACKTAB_VER="1.9.0"

# Selenium's sources at the revision chromedriver's atoms (third_party/selenium-atoms) are built
# from (its README.chromium), for building them without Closure Compiler (see the eclass's src_prepare).
SELENIUM_COMMIT="c0b8ff6451419542dcecc53c922e1a79e4dc3940"

inherit chromium-llm

DESCRIPTION="Open-source version of Google Chrome web browser"
HOMEPAGE="https://www.chromium.org/"

# https://gitweb.gentoo.org/proj/chromium-tools.git/tree/get-chromium-licences.py @ 155.0.8059.40
# (newest SPDX data available for M156 at the time), merged with the previous list.
LICENSE="Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL Old-MIT PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
LICENSE+=" rar? ( unRAR )"

SLOT="stable"
KEYWORDS="~amd64 ~arm64"

# Security fixes this version hasn't got yet, applied first (see their headers).
CHROMIUM_FIXES=(
	chromium-157-cve-2026-76026.patch
	chromium-157-cve-2026-119270.patch
	chromium-157-svg-image-retain.patch
	chromium-157-media-controls-read-only.patch
	chromium-157-display-lock-trace.patch
	chromium-157-skia-region-conic-oob.patch
	chromium-157-fsa-block-dot-cache.patch
	chromium-157-encoding-detector-tld-hint.patch
	chromium-157-paste-svg-use-sanitize.patch
	chromium-157-v8-template-object-writes.patch
	chromium-157-webrtc-empty-network-manager.patch
	chromium-157-length-calc-value-gc.patch
	chromium-157-image-fetcher-no-symlinks.patch
	chromium-157-skia-sksl-rp-branches.patch
	chromium-157-skia-graphite-clip-inflation.patch
	chromium-157-background-fetch-cors-retry.patch
	chromium-157-gpu-copy-shared-image-empty-rects.patch
)

# The overlay's patches, after the Gentoo patchset's common ones.
CHROMIUM_PATCHES=(
	# Chromium must not download executable code at runtime (other than
	# what web pages themselves load): Widevine CDM, Screen AI, SODA,
	# TranslateKit, the WASM TTS engine, component-extension JS updates
	# and the remote DevTools front-end.
	chromium-157-no-runtime-executable-downloads.patch
	chromium-157-v8-metagen-resource-dir.patch
	# V8's keyword table generator, for the system gperf (see the eclass's src_prepare).
	chromium-156-v8-keywords-gperf.patch
	# OpenXR includes <vulkan/vulkan.h> without depending on Chromium's Vulkan headers.
	chromium-156-openxr-vulkan-headers.patch
	# GN arg enable_webui_lint, to skip the ESLint/Stylelint checks (see the eclass).
	chromium-156-webui-lint-arg.patch
	# DevTools' Puppeteer without api-extractor's type declaration rollups (see the eclass).
	chromium-156-devtools-puppeteer-no-type-rollups.patch
	# ts-proto's protoc plugin comes from dev-util/chromium-node-modules (see the eclass).
	chromium-156-ts-proto-from-source.patch
	# Skia's AVX-512 kernels stay AVX-512 when CFLAGS contain -march.
	chromium-156-skia-avx512-feature-flags.patch
	# Deterministic output for DevTools' NativeFunctions.ts generator (see the eclass).
	chromium-156-devtools-natives-sorted.patch
	# GN arg angle_vulkan_mock_icd (see the eclass's chromium_configure).
	chromium-156-angle-mock-icd-arg.patch
	# "Restore pages?" only while the last session's crash is pending (see the patch).
	chromium-156-crash-bubble-once.patch
	# BoringSSL's generators, run offline from the tarball (see the eclass).
	chromium-156-boringssl-pregenerate-offline.patch
	chromium-156-boringssl-curve25519-tables.patch
	# A reproducible header for ICU's generated rbbirpt.h (see the eclass).
	chromium-156-icu-rbbicst-header.patch
)

# Copium's patches (with the system toolchain).
CHROMIUM_COPIUM_PATCHES=(
	cr145-iwyu-dev_t.patch
	cr147-simdutf-8.0-base-char.patch
	cr148-rust-1.95-bytemuck.patch
	cr152-unbundle-minizip-undo-unicode.patch
	cr152-unbundle-opus-devtools.patch
	cr153-unbundle-opus-iamf.patch
	cr156-unbundle-icu-remoting.patch
	cr156-v8-no-san-trap.patch
)

# With the system toolchain, after the Gentoo patchset's other categories.
CHROMIUM_TOOLCHAIN_PATCHES=(
	# Use the system Crubit (dev-util/crubit) with the prebuilt system Rust stdlib
	# (generates the stdlib's C++ bindings from its .rmeta files); see the patch header.
	chromium-157-system-crubit.patch
)

# With USE=hardened.
CHROMIUM_HARDENED_PATCHES=(
	# Seccomp-BPF: no writable+executable memory in sandboxed processes that
	# don't need a JIT; renderers and V8-running service processes keep it
	# unless V8 runs jitless (JavaScript JIT disabled for the site) (from
	# Hexavalent / Vanadium; see the patch headers). Plus V8's WebAssembly
	# interpreter for sites with JIT disabled.
	chromium-156-hardened-0178-seccomp-restrict-dynamic-code.patch
	chromium-156-hardened-0183-seccomp-restrict-dynamic-code-support.patch
	chromium-156-hardened-0212-wasm-interpreter-without-jit.patch
	# Page info bubble toggles for the JavaScript JIT and optimizer site
	# settings (JIT off makes the above apply to that site).
	chromium-156-hardened-page-info-jsjit.patch
	chromium-156-hardened-page-info-jsopti.patch
	# -fstack-protector-strong instead of -fstack-protector
	chromium-156-hardened-stack-protector-strong.patch
	# From Vanadium, unchanged: component updates only over HTTPS; strict
	# origin isolation and origin-keyed processes; Local Network Access
	# checks for WebRTC; Certificate Transparency enforcement, using the
	# log list from the PKI Metadata component.
	chromium-156-hardened-vanadium-0120-require-https-component-updates.patch
	chromium-156-hardened-vanadium-0127-strict-origin-isolation.patch
	chromium-156-hardened-vanadium-0244-certificate-transparency.patch
	chromium-156-hardened-vanadium-0245-local-network-access-checks.patch
	chromium-156-hardened-vanadium-0250-origin-keyed-processes.patch
	# From Vanadium, unchanged: Safe Browsing off by default (it can be turned
	# on in settings; SCT auditing for CT follows it), and no opt-in offer
	# for Safe Browsing extended reporting.
	chromium-156-hardened-vanadium-0086-no-safe-browsing-reporting-opt-in.patch
	chromium-156-hardened-vanadium-0087-safe-browsing-off-by-default.patch
)

# Bundled sources kept besides the eclass's list.
CHROMIUM_KEEPLIBS=(
	third_party/sframe
)

# Called by src_prepare with the system toolchain, after the patches: points the files
# chromium-157-system-crubit.patch and cr152-fix-rust-2-oxidize-harder.patch add or change at the selected Rust's rustfmt
# ($1: its suffix, as for bindgen in src_prepare).
chromium_crubit_rustfmt() {
	local f
	for f in build/rust/gni_impl/crubit_shared_args.gni build/rust/std/prebuilt_std_bindings.gni; do
		sed -i "s|/rustfmt\"|/rustfmt${1}\"|" "${f}" && grep -q "/rustfmt${1}\"" "${f}" ||
			die "Failed to update rustfmt path for Crubit in ${f}"
	done
}
