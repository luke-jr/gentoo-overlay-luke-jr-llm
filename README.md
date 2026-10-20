# luke-jr-llm: Chromium 156 overlay

Gentoo overlay (repository name `luke-jr-llm`), maintained with an LLM; not an official Gentoo
repository and not maintained by Gentoo developers. Example `/etc/portage/repos.conf/luke-jr-llm.conf`:

```ini
[luke-jr-llm]
location = /var/db/repos/luke-jr-llm
masters = gentoo
auto-sync = no
```

`www-client/chromium-156.0.8078.47_pre`, based on `::gentoo`'s `chromium-151.0.7922.169-r1`
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
| `www-client/chromium-156.0.8078.47_pre` | the browser: 156.0.8078.47, which has no source tarball yet, built from the 156.0.8078.12 tarball plus `files/chromium-156.0.8078.12-to-156.0.8078.35.patch` and `files/chromium-156.0.8078.35-to-156.0.8078.47.patch` (the upstream changes that can affect a Linux build; see their headers). `_pre` sorts below the real release, which replaces it. |
| `dev-util/ragel-6.10-r100` | Ragel 6 in slot 6, installed as `ragel-6`, so it can sit next to `::gentoo`'s Ragel 7 (both are slot 0 there). Chromium's ebuild regenerates HarfBuzz's state machines with it, and HarfBuzz requires 6.10. |
| `dev-util/esbuild-0.28.2` | DevTools needs exactly this version. `::gentoo` stops at 0.27.3, and deps.gentoo.zip has no vendor tarball, so this uses `EGO_SUM`. |
| `dev-build/gn-0.2578` | 156's `.gn` needs gn ≥ 1b0f22ec. Pinned to the commit Chromium's `DEPS` uses, via git-r3, because there is no tarball and gitiles archives aren't reproducible. |
| `dev-lang/typescript:6.0.2` | TypeScript 6 (the JavaScript implementation: compiler, language server, JavaScript API) built from source the way upstream builds its npm package; `::gentoo`'s `dev-lang/typescript` installs the npm package's prebuilt bundles. DevTools' build uses its JavaScript API (`collect-ui-strings`). `lib*.d.ts`, `typesMap.json` and the localized messages are byte-identical to npm's; `typescript.d.ts` differs in formatting only (upstream formats it with dprint's prebuilt WebAssembly plugin). |
| `dev-lang/typescript:7.0.2` | TypeScript 7 (the Go compiler, `tsgo`) built from source, slotted per exact version beside `::gentoo`'s TypeScript 6. Upstream compiles all WebUI/DevTools TypeScript with a prebuilt `tsgo`. The output was verified byte-identical to upstream's binary across all ~17k TypeScript outputs. |
| `dev-util/crubit:1.98.1` | Crubit's `cc_bindings_from_rs`, built from source against the selected `dev-lang/rust`. It links the compiler's own crates (the `rustc-dev` component), which it unpacks at build time from the tarball `dev-lang/rust` builds with `USE=dist`; nothing extra is installed. Since M153–156, default-on code (Blink's FontFormatCheck, the Web Bundle parser, …) is Rust that C++ reaches only through Crubit-generated bindings. |
| `dev-util/rollup:4.21.0` | The Rollup bundler built from source: its CLI (rollup's TypeScript plus the 17 npm packages its own build bundles in, each from its source, bundled with esbuild) and its JavaScript parser (Rust) as a native Node.js addon. Replaces `@rollup/wasm-node` (generated JavaScript and a prebuilt WebAssembly parser), used for WebUI bundling; chromium-bidi's own (newer) copy is replaced by the same one. WebUI bundles are byte-identical to the npm package's; the BiDi mapper only keeps a little more dead code. Replaces `dev-util/rollup-native` (parser only). |
| `dev-util/chromium-node-modules:156` | Generated files of the npm packages in Chromium's tarball and of the JavaScript libraries DevTools vendors, built from the packages' git sources, installed at the paths of the files they replace (`tree/`; Chromium copies them over, after checking versions in `VERSIONS`) or as inputs for Chromium's own rebuild steps (`build/`). Built once per Chromium major version. Build tools: terser (WebUI/Mojo minification), chromium-bidi's three rollup plugins (31 packages, incl. moment and lodash), WebUI's `postcss-selector-parser`, ts-proto's protoc plugin (bootstrapped: its committed, self-generated descriptors are regenerated and must reach a fixpoint), DevTools' build tools (cssnano's and svgo's generated packages, yargs and its family, js-yaml, uuid, esbuild's JavaScript API). Shipped code: zod and mitt (BiDi mapper), `@bufbuild/protobuf`'s ES modules, WebUI's lit and DevTools' lit (with lit's own rollup configs), and DevTools' acorn, CodeMirror 5 runmode, `diff_match_patch`, intl-messageformat, json5, marked, wasmparser, Puppeteer and Puppeteer Replay (with mitt, parsel, rxjs, urlpattern-polyfill), the 41 packages of `codemirror.next` (Lezer parsers regenerated from their grammars), and Lighthouse 13.5.0 (`lighthouse-dt-bundle.js`, the report renderer and generator, legacy-javascript) with the ~40 npm packages its build bundles and axe-core 4.13.0 (Lighthouse's accessibility engine, with the ~25 packages it bundles; emoji-regex's pattern made from Unicode's `emoji-test.txt`). |
| `dev-util/gnrt:156` | Chromium's own `gnrt` (`tools/crates/gnrt`), which writes the `BUILD.gn` files of the vendored Rust crates; the Chromium ebuild runs `gnrt gen` instead of using the checked-in ones (all 269 come out byte-identical). Built from the Chromium tarball (only that directory is unpacked) without its crate downloader (`files/gnrt-156-no-download.patch`), which drops 137 of its 268 crates (HTTP, TLS). |
| `dev-util/chromium-rust-crates:156` | The generated code and data of the vendored Rust crates, regenerated with their upstream generators at the commits the crates were published from, and installed at the paths of the files they replace (Chromium copies them over, after checking versions). syn's visitors, the Unicode tables of regex-syntax (ucd-generate), unicode-ident and unicode-width, RustFFT's SIMD butterflies, fontations' table code (read-fonts, write-fonts, skrifa), ICU4X's baked data and `icu_capi`'s generated FFI code, temporal_rs' time zone data and `zoneinfo64.res` (ICU's `genrb`). The generators' 229 crates are fetched; the rest of their lockfiles are stubs. |
| `media-video/ffmpeg-chromium-156` | for `USE=ffmpeg-chromium` (`::gentoo` stops at 154) |

All except `ffmpeg-chromium` are **build-time only** (`BDEPEND`) for Chromium. `ffmpeg-chromium` is a runtime
dependency, and only with `USE=ffmpeg-chromium`; it builds and installs, but hasn't been tested in use.

Everything is keyworded `~amd64 ~arm64`. Only amd64 has been built and tested.

`eclass/cargo-stubs.eclass` keeps the Rust packages (`crubit`, `rollup`, `gnrt`, `chromium-rust-crates`) from fetching crates
that Linux never builds (winapi, windows-sys, wasi, …): it writes a stub with the same
name, version, checksum, dependencies and features in their place, which `compile_error!`s if
anything does build it. `scripts/cargo-unused-crates.py` lists the candidates from a `Cargo.lock`.

## Build machine setup

`@chromium-build-deps` is everything needed to build Chromium, but not Chromium itself: its
`DEPEND` and `BDEPEND`, evaluated by Portage for Chromium's own USE flags (Chromium needn't be
installed). `scripts/chromium-build-deps.py --write` writes it to `/etc/portage/sets/`; to keep it
current, link the hook once and add the set to your world sets:

```sh
ln -s /var/db/repos/luke-jr-llm/scripts/postsync.d/chromium-build-deps /etc/portage/postsync.d/
/var/db/repos/luke-jr-llm/scripts/chromium-build-deps.py --write
emerge --noreplace @chromium-build-deps
```

The hook regenerates the set after every `emerge --sync`; rerun the script after changing Chromium's
USE flags. The file is only replaced after a successful evaluation, so a failure (e.g. Chromium
masked) keeps the previous set and its packages.

1. LLVM 22: `llvm-core/{llvm,clang,lld}:22` and `llvm-runtimes/compiler-rt-sanitizers:22[cfi]` (for
   `USE=official`). Set `www-client/chromium LLVM_SLOT: -* 22`.
2. `dev-lang/rust:1.98.1` with `USE="dist rustfmt"` (rustfmt is on by default). `dist`
   builds the `rustc-dev` component, which Crubit builds against. It must match *this* Rust
   build: it uses its exact `librustc_driver-<hash>.so`. Rebuilding Rust means rebuilding
   `dev-util/crubit:1.98.1` (the Chromium ebuild checks this). If you installed
   `dev-lang/rustc-dev`, unmerge it: Crubit no longer uses it.
3. Accept `~amd64` for the overlay's packages and unmask `www-client/chromium::luke-jr-llm`.
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
  - Re-checks after system tools are linked in, and **dies** on anything left over. The
    only exception is our own `tsc` from `dev-lang/typescript`; nothing prebuilt
    is allowed.
- **`chromium-156-no-runtime-executable-downloads.patch`:** Chromium never downloads or
  loads code via the component updater: Widevine CDM, Screen AI, SODA, TranslateKit, the
  WASM TTS engine, component-extension JavaScript, the Commerce Heuristics component (its
  archive carries a JavaScript file), and the remote DevTools front-end.
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
- **`chromium-156-skia-avx512-feature-flags.patch`:** Skia's AVX-512 kernels (raster pipeline,
  skcms colour transforms) get their ISA only from `-march=x86-64-v4`. With `USE=custom-cflags`,
  a `-march` in CFLAGS comes later on the command line and replaces it, so they quietly compile
  as code for that baseline (e.g. AVX2), and AVX-512 CPUs lose the AVX-512 path. The patch also
  passes the x86-64-v4 features as `-mavx512*` flags, which a later `-march` doesn't undo. The
  code still runs only after Skia's runtime CPU check, as upstream.
  - A `-mtune` in CFLAGS still applies to them. The new GN arg `avx512_tune_cpu` (default empty)
    tunes just these kernels for another CPU, e.g. `avx512_tune_cpu="znver4"` in `EXTRA_GN`.
- **`chromium-156-v8-metagen-resource-dir.patch`** plus GN args: V8 metagen uses the
  system libclang instead of a prebuilt one.
- **Unused npm packages are deleted** (`files/chromium-prune-node-modules.py`, keep list
  `files/chromium-156-node-modules.txt`): 144 of the tarball's 1329 packages (372 MiB, mostly
  generated JavaScript) are used. `scripts/chromium-node-modules-used.py` regenerates the list
  for a new version: in a built tree, it rebuilds every Node/tsc step under strace.
  - **`chromium-156-webui-lint-arg.patch`** adds the GN arg `enable_webui_lint`, which the
    ebuild sets to false. WebUI's ESLint/Stylelint checks only write stamp files, and they
    need 170 packages, including the 8.9 MB compiled TypeScript (`typescript.js`).
  - Tested on 156.0.8078.12: all 20192 outputs of the 1964 Node/tsc build steps are
    byte-identical with and without the deleted packages.
- **`keeplibs`:** new bundled *sources* `iamf_tools`, `openxr`, `chromium-bidi`,
  `typescript`; removed `bidimapper` and `v8/third_party/glibc`.
- **`generate-support-files.py`:** 156's new desktop/appdata template variables.
- **Smaller changes:**
  - **`USE=lto` (new, default on)** replaces detecting `-flto` in `CFLAGS` (`tc-is-lto`, which ran
    before the ebuild switched to clang and so was unreliable). It enables GN's ThinLTO and, with
    `USE=official`, CFI, like upstream's official builds. Any `-flto` in `CFLAGS` is always stripped.
  - PipeWire is no longer a build or runtime dependency without `USE=screencast`. Since M149 only
    the (never built) Chrome Remote Desktop host required it at `gn gen` time; `enable_remoting=false`
    avoids that, with identical build commands for chrome, chromedriver and chrome_sandbox.
  - AppStream data now goes to `/usr/share/metainfo`.
  - `LICENSE` is updated from M155 licence data.
  - Dead GN args removed (`v8_use_libm_trig_functions`, `devtools_skip_typecheck`).

No USE flags were removed. New ones:
- **`USE=hardened`** adds:
  - Vanadium's seccomp W^X restriction (0178, 0183) and the wasm-interpreter-without-JIT fix (0212).
  - `v8_enable_drumbrake=true`: V8's WebAssembly interpreter. 0212 only passes `--wasm-jitless`, which
    needs it; before, sites with JIT disabled had no WebAssembly at all (`WebAssembly is not defined`).
    DrumBrake doesn't build in 156 as is: `chromium-156-hardened-v8-drumbrake-declares-locals.patch`
    adds a method V8's debugger interface gained but the interpreter's scope iterator lacks.
  - `-fstack-protector-strong`.
  - Zero-initialised stack variables, via GN's `init_stack_vars_zero`. Official builds already have this.
  - Page info bubble toggles for the JavaScript JIT and
    optimizer site settings. Turning JIT off for a site is what makes the W^X restriction and the
    WebAssembly interpreter apply to it; otherwise only enterprise policy can.
  - From Vanadium (unchanged): Certificate Transparency enforcement (0244), component
    updates only over HTTPS (0120), strict origin isolation (0127) and origin-keyed processes (0250),
    Local Network Access checks for WebRTC (0245).
  - Also from Vanadium: Safe Browsing off by default (0087; still available in settings) and no offer to
    opt in to its extended reporting (0086). ungoogled-chromium removes Safe Browsing at build time
    instead. In Chromium, enabling CT also enables SCT auditing on desktop, which only runs with Safe
    Browsing on: it checks a sample (1 in 10,000) of visited sites' certificates with Google, so it now
    follows the Safe Browsing setting, as in Chrome.
  - With `USE=lto` and `USE=official`: CFI cast checks (`use_cfi_cast`), which upstream only uses on
    ChromeOS and Android.

Also new, for all builds: `chromium-156-disable-tos-dialog.patch` (from ungoogled-chromium) skips the
built-in terms dialog Linux builds show on a new profile's first run.

## Known issues / TODO

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
- **esbuild / typescript:** use the deprecated `EGO_SUM` for the same reason.
- **pkgcheck** reports a few inherited warnings: `llvm-r1` → `llvm-r2`, the deliberate
  `sys-libs/zlib` dependency (bug #930365), and the size of `files/`.
- **Privacy:** Chromium still talks to Google about non-Google things in the
  background. See `NOTES-runtime-downloads-and-privacy.md`; not addressed yet.
- **Deferred: "Translate this page" on pages with JavaScript disabled.** Google's translate script runs
  in an isolated world (it sees the page's DOM, but not the page's own JavaScript). Blink runs
  isolated-world scripts, XHR and event callbacks on such pages, but its timers don't fire there:
  `ScheduledAction::Execute` (`third_party/blink/renderer/core/scheduler/scheduled_action.cc`)
  checks `CanExecuteScripts()` without exempting isolated worlds, unlike `IsCallbackFunctionRunnable()`.
  So the script loads, then stalls (observed: `element.js` and the main script fetched, no
  `translateHtml` calls). A possible fix is to exempt isolated worlds there, or only the translate
  world (extension content scripts would otherwise get timers too). Untested whether it's the only
  blocker.
- **TranslateKit** (on-device Translator web API) is closed source and only ships as a downloaded binary,
  so it stays disabled for good. "Translate this page" (server-side) works.
- **Prebuilt JavaScript counts as a blob too.** Unused npm packages are deleted (see above), but
  144 remain. Every generated file of theirs that the build uses or ships is now built from source
  (`dev-util/rollup`, `dev-util/chromium-node-modules`, and in the Chromium ebuild the steps that need
  Chromium's tree); the rest are hand-written sources identical to their git tags, type declarations, or
  data (caniuse, MDN, SPDX lists, Lighthouse's locales). Shipped code built from source: WebUI's and
  DevTools' lit, `@bufbuild/protobuf` (chrome://traces-internals), Polymer's `polymer_bundled.min.js`,
  the BiDi mapper's zod and mitt, and DevTools' vendored `front_end/third_party` libraries (Lighthouse
  and axe-core, CodeMirror 5 and 6, Puppeteer, acorn, marked, …). DevTools' `ClientVariations.js` is
  regenerated with the system `protoc` and its `update_client_variations.py`. What is left, deliberately:
  - Khronos' Vulkan validation layer (for Dawn's `--enable-dawn-backend-validation`) and mock driver
    (for ANGLE's `--use-angle=vulkan-null`), mostly generated sources, are only built with
    `USE=debug` (`chromium-156-angle-mock-icd-arg.patch` adds the GN arg for the latter); upstream
    always builds and ships them, but only loads them on these debugging switches.
  - XNNPACK's ~9,400 checked-in micro-kernels (`src/*/gen/`, C and assembly) are deleted and made
    again from its templates by its own `tools/xngen` and `gemm_compiler`, plus its
    `build_identifier.c` (`files/chromium-xnnpack-regen.py`); byte-identical. The 4 that nothing
    generates (RISC-V and Hexagon kernels, not built for Linux) are left out.
  - ANGLE's checked-in generated code (entry points, format and enum tables, shader lexers/parsers and
    built-in symbol tables, its Vulkan back-end's compiled internal shaders) is regenerated with its ~30
    code generators (`files/chromium-angle-regen.py`), from inputs the tarball lacks: Khronos' XML
    registries at ANGLE's DEPS revisions, `perfect-hash` 0.2.1 (the API its symbol-table generator
    uses), and a glslang validator built from source at the revision ANGLE's prebuilt one comes from
    (2020's), so the SPIR-V is the same as upstream's. Everything a Linux build uses comes out
    byte-identical, except the two flex lexers, whose generated comments differ with Gentoo's flex.
    `src/common/Float16ToFloat32.cpp` is regenerated with the script next to it (byte-identical).
  - Chromium's own generated GPU code is regenerated in `src_prepare` with its generators: the command
    buffer (`gpu/command_buffer/build_{gles2,raster,webgpu}_cmd_buffer.py`), the GL and Vulkan bindings
    (`ui/gl/generate_bindings.py`, `gpu/vulkan/generate_bindings.py`, from `vk.xml`) and Vulkan's mojo
    types (`gpu/ipc/common/generate_vulkan_types.py`); and the X11 protocol bindings at build time from
    xcbproto's XML (`regenerate_x11_protos=true`). All byte-identical.
  - DevTools' checked-in generated TypeScript is regenerated in `src_prepare` with DevTools' own
    scripts from the tarball's inputs: `front_end/generated/` (protocol, ARIA, CSS and deprecation
    data, from the `.pdl` and `.json5` definitions; byte-identical) and
    `models/javascript_metadata/NativeFunctions.ts` (from Blink's Web IDL; newer than DevTools'
    copy, with its lists in a deterministic order, `chromium-156-devtools-natives-sorted.patch`).
    `panels/timeline/components/MetricCompareStrings.ts` says it is generated, but its generator is
    stale (the file has been edited by hand since), so it is kept as source.
  - BoringSSL's checked-in generated files are regenerated with its own generators, offline:
    `util/pregenerate` (`gen/`: the assembly from its perlasm scripts with the system Perl, the
    error-string table, the source lists; `chromium-156-boringssl-pregenerate-offline.patch`),
    `make_tables.go` and `objects.go` (EC and OID tables), and `make_curve25519_tables.py`, which
    `chromium-156-boringssl-curve25519-tables.patch` brings in line with the hand edits made to its
    output when BoringSSL moved into the `bssl` namespace. All byte-identical (`gen/sources.*` lacks
    the test files the tarball leaves out). `crypto/hrss/asm/poly_rq_mul.S` is kept as source: it is
    the output of the HRSS authors' `poly_rq_mul.py` (in the NTRU repository), but BoringSSL has
    edited it by hand since 2018 (its own scratch-space handling, CET, bug fixes). For the Fiat files
    see the exceptions below.
  - `third_party/lottie/lottie_worker.js`: Chromium's own readable copy of lottie-web 5.5.2's player,
    modified to run in a worker, reformatted, and maintained in place (minified at build time by
    Chromium's script): source, with no upstream build to redo.
  - The vendored Rust crates' generated files are regenerated by `dev-util/chromium-rust-crates`
    (316 files). All byte-identical except: regex-syntax's tables write two characters as `\u{…}`
    escapes (today's Rust escapes them when printing), and RustFFT's butterflies have LF line
    endings (the published crate has CRLF). Inputs: Unicode's UCD 16.0.0 and 17.0.0, CLDR's JSON
    (`cldr-core`, `cldr-misc-full` 48.2.0) and ICU's export data (`icuexportdata` 78.1rc) for
    ICU4X, IANA's tzdata 2025c, ICU's `zoneinfo64.txt` for 2025c. CLDR's JSON and ICU's export data
    are themselves generated upstream (by Java tools that need ICU4J and Maven jars, whose own data is
    generated from ICU's): Unicode's published release data counts as source. ICU4X's code point
    tries are built with the system ICU4C instead of its prebuilt WebAssembly module. Kept as source:
    pxfm's constants (computed once with SageMath, Sollya and Mathematica). skrifa's autohint styles
    were edited by hand after they were generated (`pub(super)`): its script is patched to match.
  - The Babel passes that lower code for old browsers are left out (axe-core, and Puppeteer's
    `es5-iife` bundle, which nothing loads); Chromium runs the modern code. axe-core's polyfills stay
    in, but only apply where a feature is missing.
  - Chromium's bundled ICU: its generated files are regenerated in `src_prepare`
    (`files/chromium-icu-regen.sh`), the way ICU's `unidata/generate.sh` and Chromium's
    `make_data_all.sh` make them. ICU's preprocessed Unicode data (`ppucd.txt`, the normalization
    inputs) from Unicode 17.0.0's release files (UCD, IDNA, security and emoji data) with ICU's
    `preparseucd.py`; the property, normalization and collation data built from it (C headers and
    the binary inputs of the data package) with `gennorm2` and ICU's `genprops` and `genuca` (13
    files fetched from ICU's repository, which its releases leave out); `collunsafe.h`, the rule
    parser tables and `urename.h` with ICU's tools; and `icudtl.dat` with Chromium's data filter.
    All byte-identical except `collunsafe.h` (its version string) and `urename.h` (without the
    names of ICU's layout engine, which isn't built; upstream copies them in by hand). The tools
    are built with the checked-in data and regenerate it unchanged (a bootstrap, as for a
    compiler). Kept as they are, as Unicode's published release data: the locale data ICU converts
    from CLDR with its Java tools (`source/data/*/*.txt`, `FractionalUCA.txt`, `UCARules.txt`,
    `localefallback_data.h`).
  - `third_party/material_web_components` (npm-built Material Web): used only by ChromeOS WebUI, not
    by this build.
  - Dawn's and Tint's 114 generated `BUILD.gn` files are regenerated with Dawn's
    `tools/src/cmd/gen` (Go, offline; the two Go modules it imports come from SRC_URI, checked
    against Dawn's `go.sum`). Byte-identical (existing files keep their copyright year).
  - abseil's 25 generated `BUILD.gn` files are regenerated from its `BUILD.bazel` files with
    Chromium's `convert_bazel_to_gn.py` (which parses them without Bazel). Byte-identical.
  - FFmpeg's checked-in configuration (`chromium/config/<branding>/linux/<arch>/`: `config.h`,
    `config.asm`, the codec and format lists, ...) is the output of its `configure` as Chromium's
    `build_ffmpeg.py` runs it: the one this build uses is regenerated
    (`files/chromium-ffmpeg-config.py`, with system nasm on amd64). Identical but for the compiler
    named in `CC_IDENT` and a path in a comment. The `autorename_*.c` wrappers (one `#include`
    each) and `ffmpeg_generated.gni` are file lists, so they are left as they are.
  - The Vulkan headers (`third_party/vulkan-headers`: `vulkan_*.h` and `vk_video/`, 30 files) are
    regenerated from the registry next to them with Vulkan-Docs' `genvk.py` (three files from
    Vulkan-Docs, which Vulkan-Headers leaves out). Byte-identical.
  - nasm's generated files are regenerated: `config/config-linux.h` with its `configure` and
    Chromium's `generate_nasm_configs.py` (the checked-in one came from an older `configure.ac`;
    the new one also finds glibc's `iscntrl` and `stdbool.h`), and the instruction, register,
    token and macro tables with its Perl scripts (`make perlreq`; identical but for the order of
    flags in comments, which follows Perl's hash order). Its copy of zlib's `crc32.h` and `inffixed.h` are
    regenerated with zlib's own table writers (byte-identical).
  - libc++'s generated headers (`<format>`'s four Unicode tables, from the UCD files libc++ keeps,
    and `<version>`) are regenerated with libc++'s scripts. Byte-identical.
  - protobuf's bootstrap files (the C++ code of protoc's own protos, and the Python `_pb2` modules
    and edition defaults the build's scripts use) are regenerated with the protoc built from them,
    first thing in `src_compile`, as Chromium's `gen_extra_chromium_files.py` does; ninja then
    rebuilds what changed. Regenerating again with the rebuilt protoc gives the same files. The
    feature protos differ from the checked-in ones, made by upstream's unpatched protoc, only in
    `[[nodiscard]]` and `Swap()` inlining (as Chromium's own regenerated `descriptor.pb.h`).
  - The SPIR-V headers (Chromium's `third_party/spirv-headers` and SwiftShader's copy) are
    regenerated from the SPIR-V grammars with SPIRV-Headers' own tools (`makeExtinstHeaders.py`,
    `buildHeaders`). Byte-identical.
  - SwiftShader's Vulkan headers are regenerated: the C headers with Vulkan-Docs' `genvk.py` from
    the registry of their Vulkan-Headers releases (v1.4.355; the video headers v1.4.322), the C++
    headers with Vulkan-Hpp v1.4.355's generator (byte-identical to Vulkan-Hpp's own output).
    SwiftShader's copies differ only in whitespace (partly reformatted by hand) and, for the C++
    headers (copied from Vulkan-Headers, made from another Vulkan-Hpp commit), in spelling (hex and
    literal suffix case, a qualified name) and a macOS-only include. On amd64, Subzero's minimized
    LLVM (`third_party/llvm-subzero`, a 2016 trunk snapshot) gets its `Attributes.gen`,
    `Intrinsics.gen` and `DataTypes.h` from that revision's `llvm-tblgen` and configure, built here
    (LLVM r290449, byte-identical); its `Config/*.h` were edited by hand since (glibc `mallinfo2`,
    ABI checks) and are kept as source.
    SwiftShader's copies of libxcb's headers (`include/xcb`, partly generated by libxcb's
    `c_client.py`) are deleted; its X11 surface code uses the system's.
  - libvpx's configuration (`source/config/`, all platforms) is regenerated with Chromium's
    `generate_gni.sh` (libvpx's `configure` and `rtcd.pl`), as the ebuild already did for ppc64.
    Byte-identical; `vpx_version.h` (a `git describe` version stamp) is kept. libvpx's VP8
    probability tables are constants computed long ago (no generator exists), kept as source.
  - libaom's configuration for this arch (`source/config/linux/<arch>/config`) is regenerated with
    its CMake configure as Chromium's `cmake_update.sh` runs it, and `wedge_masks_data.inc` with
    libaom's `gen_wedge_masks_data.py`. Byte-identical; `aom_version.h` (version stamp) is kept.
  - dav1d's configuration for this arch (`config/linux/<arch>/config.{h,asm}`) is regenerated with
    Meson through Chromium's `generate_configs.py`. Byte-identical; `vcs_version.h` (version stamp)
    is kept.
  - net's generated files are regenerated: the root certificate list (`root_cert_list_generated.h`)
    from `root_stores.json` with `update_root_stores.py`, and `effective_tld_names.gperf` from the
    Public Suffix List with `tld_cleanup`, built first in `src_compile`. Both byte-identical. (base's
    `utf8_validator_tables.cc` is kept as source: its generator's data comes out the same, but the
    file has been edited by hand since.)
  - libutf's rune type tables are regenerated from the `UnicodeData.txt` it ships with its
    `mkrunetype.awk` (byte-identical); `isalpharune.c` was edited by hand since (crbug.com/1184370)
    and is kept as source.
  - tools/metrics' `setup_modules.py` shims are regenerated with its `generate_setup_modules.py`
    (the checked-in ones differ only in how a Python formatter wrapped one line).
  - The Khronos headers Chromium didn't modify (`third_party/khronos`: `GLES3/gl3*.h`, `EGL/egl.h`)
    are regenerated with the `genheaders.py` and registry XML of the Khronos commits they came from
    (generation date and commit stamps kept). `gl3.h` and `egl.h` are byte-identical; `gl31.h` and
    `gl32.h` differ in comments (copyright years, URL) the 2017 generator writes differently from the
    2016 one. Chromium's modified ones (`gl2.h`, `gl2ext.h`, `eglext.h`) are kept as source. ANGLE's
    copies (`include/`: GLES2, GLES3, EGL, GLX, WGL) are regenerated the same way, keeping ANGLE's
    includes of its own extension headers (`files/chromium-khronos-merge.py`); byte-identical. Its
    GLES1 headers, which ANGLE edited, are kept as source.
  - The Vulkan loader's and Vulkan-Utility-Libraries' generated sources are regenerated from
    `third_party/vulkan-headers`' registry with their `generate_source.py`, which formats them with
    clang-format. Byte-identical.
  - OpenXR's generated headers and loader dispatch code are regenerated from its registry with
    OpenXR-SDK-Source's generators (at the SDK's release). Byte-identical.
  - FreeType's `pstables.h` (and pdfium's copy of it) is regenerated with FreeType's `glnames.py`,
    pdfium's OpenJPEG `t1_luts.h`/`t1_ht_luts.h` and libtiff `tif_fax3sm.c` with OpenJPEG's
    `t1_generate_luts` and libtiff's `mkg3states`, fetched at the revisions pdfium bundles; libtiff's
    `tiffconf.h` is a configure output edited by hand since and is kept as source.
  - FlatBuffers' `reflection_generated.h` and the FlatBuffers headers of TensorFlow Lite and LiteRT
    (`schema_generated.h`, `conversion_metadata_generated.h`, `configuration_generated.h`, the
    latter's schema made from its `.proto`) are regenerated in `src_compile` with the build's
    `flatc`, with the options of upstream's rules; the builtin op lists (`builtin_ops.h`,
    `builtin_ops_list.inc`) with TensorFlow Lite's generators, also for LiteRT, which only copies
    them. The checked-in headers were made by an older `flatc` (and `conversion_metadata` from an
    older schema, without `PYTORCH` and `model_hash`), so those differ.
  - chromium-bidi's protocol types and Zod schemas (`src/protocol{,-parser}/generated`) are
    regenerated with its `tools/update_bidi_types.py` and `dev-util/cddlconv` from the CDDL in the
    WebDriver BiDi specs, extracted with the spec's `generate.js` and parse5 (6, not compiled), at
    the spec commits current when the checked-in types were made. Upstream's prettier/eslint
    formatting pass is left out; with it, the output is byte-identical.
  - Skia's generated files are regenerated with its generators: the GL interface code
    (`*Autogen.cpp`) with `tools/ganesh/gl/interface` (Go, offline), the SkSL lexer with `sksllex`,
    and the minified SkSL modules with `sksl-minify`, built with Skia's standalone GN build (only
    the SkSL compiler). All byte-identical. `src/sksl/spirv.h` is Khronos' SPIR-V 1.0 revision 4
    header, published before its generator and grammar were: kept as source.
  - V8's keyword table (`src/parsing/keywords-gen.h`) is regenerated with its
    `gen-keywords-gen-h.py` and the system gperf (`chromium-156-v8-keywords-gperf.patch` lets the
    script accept newer gperf output; only the version comment differs). Its static roots
    (`src/roots/static-roots-intl-wasm.h` and the values in `include/v8-internal.h` taken from them)
    are regenerated at the start of `src_compile` with a `mksnapshot` built in a second build
    directory with `v8_enable_static_roots_generation`, as V8's `gen-static-roots.py` does (about
    3,400 extra build steps); only a comment's indentation differs.
  - SQLite's amalgamation (`sqlite3.c`, `sqlite3.h`, the shell and `rename_exports.h`) is
    regenerated from SQLite's sources with Chromium's `generate_amalgamation.py`
    (`files/chromium-sqlite-amalgamation.py`). Byte-identical, once `SQLITE_SOURCE_ID` (a version
    stamp, which SQLite marks as modified because the tarball lacks its tests) is kept.
  - Wuffs' C library (`release/c/wuffs-v0.3.c`, Skia's GIF decoder) is regenerated from Wuffs'
    sources with its own `wuffs gen`, built from the commit that made it (Wuffs' v0.3 branch).
    Byte-identical once its version metadata, which comes from git, is kept.
  - simdutf's amalgamation (`simdutf.h`, `simdutf.cpp`) is regenerated from simdutf 7.7.0's sources
    with its `amalgamate.py`. Byte-identical but for the generation timestamp, which is kept.
  - RE2's Unicode tables are regenerated from Unicode 15.1.0's data files (RE2's version) with its
    `make_unicode_groups.py` and `make_unicode_casefold.py`, and its Perl classes with
    `make_perl_groups.pl`. Byte-identical.
  - Bison and Ragel output is regenerated: Blink's XPath parser (`rule_bison.py`), the emoji
    presentation scanner and HarfBuzz's state machines (Ragel 6.10). All byte-identical. Blink's
    `css_group_config.json5` is kept as source: its generator (from CSS usage statistics) no longer
    exists.
  - ipcz's message definitions (`node_messages.{cc,h}`) are regenerated from their
    `*_messages_generator.h` with its `node_messages.py`. Byte-identical.
  - The IME character composer's table (`ui/base/ime/character_composer_data.h`) is regenerated
    with `generate_character_composer_data.py`. Byte-identical.
  - The top domains' skeletons for the lookalike-URL check (`components/url_formatter/spoof_checks/
    top_domains/*.skeletons`) are regenerated in `src_compile` with `make_top_domain_skeletons`,
    built from the tree. Byte-identical. (Their input, `domains.list`, is Chrome UX Report data.)
  - zxcvbn's keyboard adjacency graphs are regenerated with its
    `build_keyboard_adjacency_graphs.py`. Byte-identical.
  - libzip's error strings (`zip_err_str.c`) are regenerated with its CMake script. Byte-identical.
    Its `zipconf.h` and `config.h` are configure output edited by hand since, kept as source.
  - libwayland's `include/config.h` is regenerated with its Meson configure (`USE=wayland`). It
    finds glibc's `gettid()`, which the checked-in one doesn't; otherwise identical.
  - The extension APIs' TypeScript declarations that still match their schema (9 files) are
    regenerated with `tools/json_schema_compiler` (`-g ts_definitions`); they differ only in the
    copyright year, a trailing blank line and the command named in a comment. `storage`,
    `extension_types`, `metrics_private` and `web_request` were edited by hand since or lag their
    schema, and the partially generated ones were edited by hand: kept as source.
  - Glic's generated TypeScript API enums (`glic_api_generated.ts` and a block of `glic_api.ts`) are
    regenerated from its mojom definitions with its `generate.py`. Byte-identical.
  - Jinja's identifier pattern (`third_party/jinja2/_identifier.py`) is regenerated with its
    `generate_identifier_pattern.py`, from the build's Python's Unicode data (newer than the checked-in
    one's; only non-ASCII template identifiers are affected).
  - Bundled HarfBuzz's Unicode tables (`USE=-system-harfbuzz`) are regenerated from Unicode 17.0.0's
    data with its `gen-*.py` and packTab 1.9.0. Byte-identical. Kept as source: its OpenType language
    tag table (from Microsoft's and IANA's registries, whose old versions aren't published) and its
    OS/2 Unicode ranges (from a table copied from the OpenType spec).
  - chromedriver's Selenium atoms (`third_party/selenium-atoms`, minified JavaScript compiled by
    Selenium's Bazel build with Closure Compiler, which isn't available from source) are built from
    Selenium's sources without it (`files/chromium-selenium-atoms.py`): the Closure files each atom
    needs, uncompiled, in dependency order, minified with esbuild, run in a scope of their own. They
    give the same results, but are about 25 times larger, so element commands (find element, get
    text, ...) take about four times as long. `USE=prebuilt-chromedriver-atoms` keeps upstream's.
  - DevTools' Puppeteer type declarations come from `dev-util/chromium-node-modules`' Puppeteer build
    (with `devtools-protocol`'s declarations made from its `.pdl` definitions), byte-identical;
    api-extractor's rollups of them (`types.d.ts`, `es5-iife/puppeteer-core-browser.d.ts`), which
    nothing imports, are left out.

  Where sources come from:
  - Lighthouse's `@paulirish/trace_engine` (DevTools' trace engine, which is only published compiled)
    is recompiled from the TypeScript its source maps hold (the original text of each file, shipped
    in the npm package), so its ~144 sources aren't downloaded separately. That text is DevTools'
    commit 845cad7, 25 minutes before the release, plus the edits of an unpublished packaging script
    (`files/lighthouse-trace-engine-0.0.65-packaging.patch`): checked byte-identical for all 144 with
    `files/lighthouse-trace-engine-sources.mjs verify`. `generated/protocol.ts` has no map (it compiles
    to nothing, but its const enum values are inlined): it is generated with DevTools' generator at
    that commit from the protocol's `.pdl` definitions (the `devtools-protocol` npm package, which
    publishes them per Chromium revision) via inspector_protocol's `concatenate_protocols.py`.
  - Lighthouse's deprecation strings come from DevTools' `generated/Deprecation.ts`, generated here
    with DevTools' `generate_deprecations.py` from Blink's `deprecation.json5` (`dev-python/json5`).
  - `http-link-header` 1.1.1 comes from a fork that still has its commit, since the original repository
    is gone.
  - emoji-regex's pattern is generated with `files/emoji-test-regex-pattern.mjs`, not upstream's
    downloaded PHP tool, from Unicode's `emoji-test.txt` as `app-i18n/unicode-emoji` installs it. It is 13.8 KB vs upstream's 14.1 KB, and matches the same on 210,452 test
    strings.
- **Generated files used as is (exceptions).** Every other generated file the build uses is
  regenerated from its inputs, or replaced (see above). These are not, by kind:
  - *Proofs and math constants.* BoringSSL's Fiat Cryptography code (`third_party/fiat/`:
    `curve25519_64.h`, `p256_64.h`, `p256_field_64.br.c.inc`, `p256_point.br.c.inc`; extracted from
    Coq proofs, so regenerating it means building Fiat Cryptography with Coq). Numeric tables computed
    once with math software or by hand: pxfm's and llvm-libc's polynomial coefficients
    (SageMath, Sollya, Mathematica), libc++'s Ryu tables, WebRTC's numpy/MATLAB tables, V8's CRC32
    table, abseil's Randen round keys, libvpx's VP8 probability tables, and Opus' static CELT modes
    (`celt/static_modes_float.h`: window and twiddle constants, which Opus keeps fixed; regenerating
    them changes the codec's arithmetic in the last digit).
  - *Published data, used as input.* Unicode's release data (UCD, CLDR's JSON, ICU's
    `icuexportdata`, ICU4C's locale data `.txt`; their converters are Java tools needing ICU4J), the
    Public Suffix List, Chrome UX Report's top domain list, Chromium's root store definitions, and
    `.proto` files (including copies exported from Google's internal repository).
  - *No public generator.* abseil's Gaussian distribution tables (its generator was never
    published), libaddressinput's region metadata (from Google's address data service), CLD3's and
    CED's script/encoding tables, `components/google/core/common/google_tld_list.h`,
    `services/tracing/perfetto/privacy_filtered_fields-inl.h`, the QUICHE feature flag list and
    Autofill's i18n model (Google-internal exports), the Linux syscall tables in
    `sandbox/linux/system_headers`, Crubit's support `BUILD.gn` files (Google-internal
    `bazel_to_builds`), Skia's `src/sksl/spirv.h` (SPIR-V 1.0 revision 4, published before its
    generator and grammar were), HarfBuzz's OpenType language tag table (from Microsoft's and IANA's
    registries, whose old versions aren't published) and OS/2 Unicode ranges (from a table copied from
    the OpenType spec), and Blink's `css_group_config.json5` (its generator, from CSS usage
    statistics, is gone).
  - *Edited by hand since they were generated* (their generators would undo the edits): DevTools'
    `MetricCompareStrings.ts`, BoringSSL's `crypto/hrss/asm/poly_rq_mul.S`, llvm-subzero's
    `Config/*.h`, libutf's `isalpharune.c`, the Khronos headers Chromium modified (`GLES2/gl2.h`,
    `gl2ext.h`, `EGL/eglext.h`) and ANGLE's GLES1 headers, base's `utf8_validator_tables.cc`, V8's
    `unicode.cc`, chromedriver's `network_list.cc`, the configure output edited for Chromium
    (libtiff's `tiffconf.h`, libzip's `zipconf.h` and `config.h`, snappy's
    `snappy-stubs-public.h`), the TypeScript declarations of the `storage`, `extension_types`,
    `metrics_private` and `web_request` extension APIs (and the partially generated ones), and
    Polymer's and the iron/paper elements' typings (hand-maintained upstream since 2020, or frozen
    2018–2019 output, then patched by Chromium's `chromium_dts.patch`).
  - *Version stamps* in otherwise regenerated files are kept: libvpx's `vpx_version.h`, libaom's
    `aom_version.h`, dav1d's `vcs_version.h`, Dawn's commit hash, `gpu_lists_version.h`, the Khronos
    headers' date and commit lines, SQLite's `SQLITE_SOURCE_ID`, Wuffs' version metadata, simdutf's
    generation timestamp.
  - *Lists of files*, which count as source: Skia's `gn/*.gni`, `.pydeps`/`.gritdeps`, FFmpeg's
    `ffmpeg_generated.gni` and `autorename_*` wrappers, XNNPACK's `BUILD.gn` (exported from Bazel:
    its micro-kernel lists and their flags).
  - *Not built or not used by default:* Khronos' Vulkan validation layer and mock driver (only with
    `USE=debug`), catapult's telemetry `BUILD.gn` (test targets), perfetto's syntaqlite parser,
    `third_party/material_web_components` (ChromeOS only).
  - *Binary assets* (images, icons, sounds; also the dino game's encrypted alternate images,
    `components/error_page/common/alt_game_image_data.cc`) and *ML models* (Blink's dark mode
    classifier, Opus' `mlp_data.c`) are out of scope.
  - With `USE=prebuilt-chromedriver-atoms`, chromedriver uses upstream's Closure-compiled Selenium
    atoms instead of the ones built from source.
- **Crubit notes:** see `NOTES-crubit.md`.
- **Metadata:** no package lists a maintainer: the `::gentoo` ones' Gentoo maintainers were removed, since
  they don't maintain this overlay. Add yourself if you like. The generated AppStream data uses upstream
  Chromium's contact and bug-report URL instead of Gentoo's. `metadata/md5-cache` isn't tracked in git; Portage
  regenerates it (or run `egencache`).
