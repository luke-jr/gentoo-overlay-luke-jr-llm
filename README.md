# Chromium 156 overlay

`www-client/chromium-156.0.8078.12`, based on `::gentoo`'s `chromium-151.0.7922.169-r1`
(`::gentoo` has masked Chromium for removal on 2026-10-24, bug #982204).

Goals:
- Build without any bundled or third-party prebuilt binaries.
- Chromium must not download executable code at runtime, apart from
  JavaScript/WebAssembly that web pages themselves load.
- Keep upstream behaviour and features otherwise. In particular, the omnibox
  **AI Mode** button stays.

## Packages

| Package | Why |
|---|---|
| `www-client/chromium-156.0.8078.12` | the browser |
| `dev-util/esbuild-0.28.2` | DevTools needs exactly this version. `::gentoo` stops at 0.27.3, and deps.gentoo.zip has no vendor tarball, so this uses `EGO_SUM`. |
| `dev-build/gn-0.2578` | 156's `.gn` needs gn ≥ 1b0f22ec. Pinned to the commit Chromium's `DEPS` uses, via git-r3, because there is no tarball and gitiles archives aren't reproducible. |
| `dev-lang/typescript-native-7.0.2` | TypeScript 7 (`tsgo`) built from source. Upstream compiles all WebUI/DevTools TypeScript with a prebuilt `tsgo`. The output was verified byte-identical to upstream's binary across all ~17k TypeScript outputs. |
| `dev-util/crubit:1.98.1` | Crubit's `cc_bindings_from_rs`, built from source against the selected `dev-lang/rust`. Since M153–156, default-on code (Blink's FontFormatCheck, the Web Bundle parser, …) is Rust that C++ reaches only through Crubit-generated bindings. |
| `media-video/ffmpeg-chromium-156` | for `USE=ffmpeg-chromium` (`::gentoo` stops at 154) |

All except `ffmpeg-chromium` are **build-time only** (`BDEPEND`) for Chromium. `ffmpeg-chromium` is a runtime
dependency, and only with `USE=ffmpeg-chromium`; it builds and installs, but hasn't been tested in use.

Everything is keyworded `~amd64 ~arm64`. Only amd64 has been built and tested.

## Build machine setup

1. LLVM 22: `llvm-core/{llvm,clang,lld}:22` and `llvm-runtimes/compiler-rt-sanitizers:22[cfi]` (for
   `USE=official`). Set `www-client/chromium LLVM_SLOT: -* 22`.
2. `dev-lang/rust:1.98.1` with `USE="dist rustfmt"` (rustfmt is on by default). `dist`
   installs the `rustc-dev` component under `/usr/lib/rust/1.98.1/dist/`, which Crubit
   builds against. It must be *this* Rust build: Crubit links its exact
   `librustc_driver-<hash>.so`. Rebuilding Rust means rebuilding `dev-util/crubit:1.98.1`
   (the Chromium ebuild checks this).
3. Accept `~amd64` for the overlay's packages and unmask `www-client/chromium::local`.
   `LLVM_COMPAT` is 22 only: LLVM 23 means Rust 1.99, which would need a `dev-util/crubit:1.99.0`.
4. `=dev-python/clang-22*`, pulled in automatically, used by V8's build-time
   header parser ("metagen").

## Notable ebuild changes vs. 151

- **Gentoo patchset:** forked from `chromium-patches` tag 152 into
  `files/chromium-patches-156/`.
  - Refreshed `cr152-compiler` and `cr152-fix-rust-2-oxidize-harder`; `cr151-dawn-system-go` only needed
    its context updated.
  - Dropped `cr131-unbundle-icu-target` (upstreamed; applying it with fuzz would have
    defined a GN target twice) and `cr152-revert-to-rollup-wasm` (156 no longer uses
    rollup in DevTools).
- **Copium:** updated to 027d15ff; patches selected for 156.
- **Binary removal:** `files/chromium-binary-audit.py` replaces `bin-finder.py` (which
  only handled ELF).
  - Deletes all compiled code (ELF, PE, COFF objects, Mach-O, WebAssembly, LLVM bitcode, SPIR-V,
    Java/DEX, ar archives, Python bytecode), WebAssembly embedded as base64 in JS/TS/JSON/HTML, and all
    archives (zip/jar/whl/crx, 7z, gzip, xz, bzip2, zstd), whose contents could hide any of these. Among
    them are prebuilt Clang `.tar.xz` files and a tarball copy of `node_modules`. None of the ~1,400 files
    is an input of the targets the ebuild builds.
  - Re-checks after system tools are linked in, and **dies** on anything outside a
    short, commented allowlist.
- **`chromium-156-no-runtime-executable-downloads.patch`:** Chromium never downloads or
  loads code via the component updater: Widevine CDM, Screen AI, SODA, TranslateKit, the
  WASM TTS engine, component-extension JavaScript, and the remote DevTools front-end.
  - Code downloaded by an *earlier* build in the same profile isn't loaded either (Widevine
    hint file, stored TranslateKit path; a Screen AI copy is deleted).
  - With `USE=widevine`, a CDM installed next to the browser (`/usr/lib64/chromium-browser/WidevineCdm`,
    e.g. from `www-plugins/chrome-binary-plugins`) is used directly. This is compile-tested, but not
    runtime-tested.
  - The Translator web API reports "unavailable" rather than hanging. The DevTools CSP no longer allows
    remote scripts.
  - Data components (CRLSet, filter lists, hints, …) are unaffected.
- **`chromium-156-system-crubit.patch`:** lets Chromium's GN use a system Crubit with the
  prebuilt system Rust stdlib.
  - New args `rust_crubit_root` and `rust_crubit_clang_format`.
  - The stdlib's C++ bindings are generated from its `.rmeta` files.
  - Nothing changes if the args aren't set.
- **`chromium-156-v8-metagen-resource-dir.patch`** plus GN args: V8 metagen uses the
  system libclang instead of a prebuilt one.
- **`keeplibs`:** new bundled *sources* `iamf_tools`, `openxr`, `chromium-bidi`,
  `typescript`; removed `bidimapper` and `v8/third_party/glibc`.
- **`generate-support-files.py`:** 156's new desktop/appdata template variables.
- **Smaller changes:**
  - AppStream data now goes to `/usr/share/metainfo`.
  - `LICENSE` is updated from M155 licence data.
  - Dead GN args removed (`v8_use_libm_trig_functions`, `devtools_skip_typecheck`).

No USE flags were removed.

## Known issues / TODO

- **rollup's WebAssembly build** (`@rollup/wasm-node`, from npm) is still used: by
  rollup when bundling WebUI resources, and by chromium-bidi. It's the only allowlisted
  prebuilt in `chromium-binary-audit.py`. Removing it needs rollup's parser built from
  source.
- **`USE=system-icu` doesn't work, and `::gentoo` masks it** (`profiles/base/package.use.mask`, bug #943216),
  so builds use the bundled ICU, as with 151. Unmasking it locally shows three blockers:
  1. ICU ≥ 76's C++ API uses `std::u16string_view`, which doesn't link against Chromium's own
     libc++ (`std::__Cr`), and the ebuild requires that libc++.
  2. V8's Temporal code includes ICU-internal headers (`udatamem.h`) that system ICU doesn't install.
  3. Build-time generators expect `icudtl.dat`. A GN fix for this one is shelved, since it doesn't help
     without the other two.
- **USE=bundled-toolchain** (Google's prebuilt clang/Rust) isn't adapted to the 156
  changes (e.g. its bundled clang-format is removed but referenced by Crubit). It's
  opt-in and by definition uses prebuilt binaries.
- **gn ebuild:** uses git-r3 (pinned commit). A distfile tarball would need hosting.
- **esbuild / typescript-native:** use the deprecated `EGO_SUM` for the same reason.
- **pkgcheck** reports a few inherited warnings: `llvm-r1` → `llvm-r2`, the deliberate
  `sys-libs/zlib` dependency (bug #930365), and the size of `files/`.
- **Privacy:** Chromium still talks to Google about non-Google things in the
  background. See `NOTES-runtime-downloads-and-privacy.md`; not addressed yet.
- **Crubit notes:** see `NOTES-crubit.md`.
- **Metadata:** `dev-util/crubit` and `dev-lang/typescript-native` are new packages with no maintainer
  in `metadata.xml`; add yourself if you like. `metadata/md5-cache` isn't tracked in git; Portage
  regenerates it (or run `egencache`).
