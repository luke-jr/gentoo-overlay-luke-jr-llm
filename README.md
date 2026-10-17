# luke-jr-llm: Chromium 156 overlay

Gentoo overlay (repository name `luke-jr-llm`), maintained with an LLM; not an official Gentoo
repository and not maintained by Gentoo developers. Example `/etc/portage/repos.conf/luke-jr-llm.conf`:

```ini
[luke-jr-llm]
location = /var/db/repos/luke-jr-llm
masters = gentoo
auto-sync = no
```

`www-client/chromium-156.0.8078.35_pre`, based on `::gentoo`'s `chromium-151.0.7922.169-r1`
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
| `www-client/chromium-156.0.8078.35_pre` | the browser: 156.0.8078.35, which has no Linux release or source tarball yet, built from the 156.0.8078.12 tarball plus `files/chromium-156.0.8078.12-to-156.0.8078.35.patch` (the upstream changes that can affect a Linux build; see its header). `_pre` sorts below the real release, which replaces it. |
| `dev-util/esbuild-0.28.2` | DevTools needs exactly this version. `::gentoo` stops at 0.27.3, and deps.gentoo.zip has no vendor tarball, so this uses `EGO_SUM`. |
| `dev-build/gn-0.2578` | 156's `.gn` needs gn ≥ 1b0f22ec. Pinned to the commit Chromium's `DEPS` uses, via git-r3, because there is no tarball and gitiles archives aren't reproducible. |
| `dev-lang/typescript:6.0.2` | TypeScript 6 (the JavaScript implementation: compiler, language server, JavaScript API) built from source the way upstream builds its npm package; `::gentoo`'s `dev-lang/typescript` installs the npm package's prebuilt bundles. DevTools' build uses its JavaScript API (`collect-ui-strings`). `lib*.d.ts`, `typesMap.json` and the localized messages are byte-identical to npm's; `typescript.d.ts` differs in formatting only (upstream formats it with dprint's prebuilt WebAssembly plugin). |
| `dev-lang/typescript:7.0.2` | TypeScript 7 (the Go compiler, `tsgo`) built from source, slotted per exact version beside `::gentoo`'s TypeScript 6. Upstream compiles all WebUI/DevTools TypeScript with a prebuilt `tsgo`. The output was verified byte-identical to upstream's binary across all ~17k TypeScript outputs. |
| `dev-util/crubit:1.98.1` | Crubit's `cc_bindings_from_rs`, built from source against the selected `dev-lang/rust`. It links the compiler's own crates (the `rustc-dev` component), which it unpacks at build time from the tarball `dev-lang/rust` builds with `USE=dist`; nothing extra is installed. Since M153–156, default-on code (Blink's FontFormatCheck, the Web Bundle parser, …) is Rust that C++ reaches only through Crubit-generated bindings. |
| `dev-util/rollup:4.21.0` | The Rollup bundler built from source: its CLI (rollup's TypeScript plus the 17 npm packages its own build bundles in, each from its source, bundled with esbuild) and its JavaScript parser (Rust) as a native Node.js addon. Replaces `@rollup/wasm-node` (generated JavaScript and a prebuilt WebAssembly parser), used for WebUI bundling; chromium-bidi's own (newer) copy is replaced by the same one. WebUI bundles are byte-identical to the npm package's; the BiDi mapper only keeps a little more dead code. Replaces `dev-util/rollup-native` (parser only). |
| `dev-util/chromium-node-modules:156` | Generated files of the npm packages in Chromium's tarball and of the JavaScript libraries DevTools vendors, built from the packages' git sources, installed at the paths of the files they replace (`tree/`; Chromium copies them over, after checking versions in `VERSIONS`) or as inputs for Chromium's own rebuild steps (`build/`). Built once per Chromium major version. Build tools: terser (WebUI/Mojo minification), chromium-bidi's three rollup plugins (31 packages, incl. moment and lodash), WebUI's `postcss-selector-parser`, ts-proto's protoc plugin (bootstrapped: its committed, self-generated descriptors are regenerated and must reach a fixpoint), DevTools' build tools (cssnano's and svgo's generated packages, yargs and its family, js-yaml, uuid, esbuild's JavaScript API). Shipped code: zod and mitt (BiDi mapper), `@bufbuild/protobuf`'s ES modules, WebUI's lit and DevTools' lit (with lit's own rollup configs), and DevTools' acorn, CodeMirror 5 runmode, `diff_match_patch`, intl-messageformat, json5, marked, wasmparser, Puppeteer and Puppeteer Replay (with mitt, parsel, rxjs, urlpattern-polyfill), the 41 packages of `codemirror.next` (Lezer parsers regenerated from their grammars), and Lighthouse 13.5.0 (`lighthouse-dt-bundle.js`, the report renderer and generator, legacy-javascript) with the ~40 npm packages its build bundles and axe-core 4.13.0 (Lighthouse's accessibility engine, with the ~25 packages it bundles; emoji-regex's pattern made from Unicode's `emoji-test.txt`). |
| `media-video/ffmpeg-chromium-156` | for `USE=ffmpeg-chromium` (`::gentoo` stops at 154) |

All except `ffmpeg-chromium` are **build-time only** (`BDEPEND`) for Chromium. `ffmpeg-chromium` is a runtime
dependency, and only with `USE=ffmpeg-chromium`; it builds and installs, but hasn't been tested in use.

Everything is keyworded `~amd64 ~arm64`. Only amd64 has been built and tested.

`eclass/cargo-stubs.eclass` keeps the Rust packages (`crubit`, `rollup`) from fetching crates
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
  - DevTools' checked-in generated TypeScript is regenerated in `src_prepare` with DevTools' own
    scripts from the tarball's inputs: `front_end/generated/` (protocol, ARIA, CSS and deprecation
    data, from the `.pdl` and `.json5` definitions; byte-identical) and
    `models/javascript_metadata/NativeFunctions.ts` (from Blink's Web IDL; newer than DevTools'
    copy, with its lists in a deterministic order, `chromium-156-devtools-natives-sorted.patch`).
    `panels/timeline/components/MetricCompareStrings.ts` says it is generated, but its generator is
    stale (the file has been edited by hand since), so it is kept as source.
  - `third_party/lottie/lottie_worker.js`: Chromium's own readable copy of lottie-web 5.5.2's player,
    modified to run in a worker, reformatted, and maintained in place (minified at build time by
    Chromium's script): source, with no upstream build to redo.
  - The Babel passes that lower code for old browsers are left out (axe-core, and Puppeteer's
    `es5-iife` bundle, which nothing loads); Chromium runs the modern code. axe-core's polyfills stay
    in, but only apply where a feature is missing.
  - `third_party/material_web_components` (npm-built Material Web): used only by ChromeOS WebUI, not
    by this build.
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
- **Crubit notes:** see `NOTES-crubit.md`.
- **Metadata:** no package lists a maintainer: the `::gentoo` ones' Gentoo maintainers were removed, since
  they don't maintain this overlay. Add yourself if you like. The generated AppStream data uses upstream
  Chromium's contact and bug-report URL instead of Gentoo's. `metadata/md5-cache` isn't tracked in git; Portage
  regenerates it (or run `egencache`).
