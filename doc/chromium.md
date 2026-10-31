# www-client/chromium

How this overlay's Chromium ebuilds differ from `::gentoo`'s, how to set up a machine to build them,
and what is still open. The generated and prebuilt files are in `doc/chromium-generated-files.md`.

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

The set is for the newest visible Chromium. The hook regenerates it after every `emerge --sync`;
rerun the script after unmasking a new version or changing Chromium's USE flags. The file is only replaced after a successful evaluation, so a failure (e.g. Chromium
masked) keeps the previous set and its packages.

1. LLVM 22: `llvm-core/{llvm,clang,lld}:22` and `llvm-runtimes/compiler-rt-sanitizers:22[cfi]` (for
   `USE=official`). Set `www-client/chromium LLVM_SLOT: -* 22`.
2. `dev-lang/rust:1.98.1` with `USE="dist rustfmt"` (rustfmt is on by default). `dist`
   builds the `rustc-dev` component, which Crubit builds against. It must match *this* Rust
   build: it uses its exact `librustc_driver-<hash>.so`. Rebuilding Rust means rebuilding
   the installed `dev-util/crubit` versions (the Chromium ebuild checks this). If you installed
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
- **`USE=openxr`** (off by default): WebXR's immersive sessions (VR headsets) through an OpenXR
  runtime such as Monado. Upstream builds OpenXR and the XR device service on Linux
  (`enable_openxr`, `enable_vr`) but turns OpenXR on at runtime only on Windows
  (`chrome://flags/#openxr` elsewhere), and Gentoo has no OpenXR runtime packaged; OpenXR is the
  only XR runtime on Linux. Without the flag neither is built, and the OpenXR SDK (for
  regenerating its generated files) isn't fetched. Inline WebXR, which needs no device, stays.
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

Also new, for 156: `chromium-156-disable-tos-dialog.patch` (from ungoogled-chromium) skips the
built-in terms dialog Linux builds show on a new profile's first run (157 does the same upstream).

`chromium-156-crash-bubble-once.patch` fixes an upstream bug: after a crash and a restore from
the "Restore pages?" bubble, a window opened later through the startup path (running `chromium`
again, a launcher) offered to restore again. `HasPendingUncleanExit()` relied on
`ProfileLaunchObserver`, which forgets the launched profiles once startup is done; it now also
requires `ExitTypeService` to still be waiting for the user to acknowledge the crash.

## 157

The 157 ebuild is the 156 one with these differences:
- Patches rebased for 157: `chromium-157-no-runtime-executable-downloads.patch`,
  `chromium-157-system-crubit.patch` (157 moved Crubit's tool paths into
  `build/rust/gni_impl/crubit_shared_args.gni`, and its bindings need a `std_bindings_crubit_metadata`
  target, which the patch adds for the system stdlib), `chromium-157-v8-metagen-resource-dir.patch`,
  and the Gentoo patchset as `files/chromium-patches-157/` (`cr149-bindgen-libclang-paths` and
  `cr152-fix-rust-2-oxidize-harder` rebased).
- Dropped, as 157 doesn't need them: the 156 branch fixes and the CVE-2026-110914 patch (in 157),
  the terms dialog patch (upstream does the same), DrumBrake's `DeclaresLocals()` patch, and copium's
  `cr143-libsync-__BEGIN_DECLS.patch` (no effect).
- `third_party/sframe` is kept as a bundled source (157 builds it).
- Bundled HarfBuzz's tables and `unicode-ident` are made from Unicode 18.0.0 (its zipped UCD isn't
  published yet; the files come from Unicode's `unicodetools` repository). 157's checked-in HarfBuzz
  USE table was made from 17.0.0's `DerivedCoreProperties.txt`, so that one table differs.
- Newer pins: gn 0.2595, Crubit 20260930, Vulkan-Headers and Vulkan-Docs v1.4.365, cddlconv 0.2.0 (chromium-bidi) and
  0.1.10 (`webdriver-bidi-protocol`), zod 4.6.5 and puppeteer-core 25.13.0 in
  `dev-util/chromium-node-modules:157`, syn 3.0.6, unicode-ident 1.0.26 and fontations' newer crates
  in `dev-util/chromium-rust-crates:157`.

Built offline and runtime-tested like 156 (components, DevTools, WebDriver BiDi, translation, WebGL).

## Known issues / TODO

- **`USE=system-icu` doesn't work, and `::gentoo` masks it** (`profiles/base/package.use.mask`, bug #943216),
  so builds use the bundled ICU, as with 151. Unmasking it locally shows three blockers:
  1. ICU ≥ 76's C++ API uses `std::u16string_view`, which doesn't link against Chromium's own
     libc++ (`std::__Cr`), and the ebuild requires that libc++.
  2. V8's Temporal code includes ICU-internal headers (`udatamem.h`) that system ICU doesn't install.
  3. Build-time generators expect `icudtl.dat`. A GN fix for this one is shelved, since it doesn't help
     without the other two.
- **`USE=ffmpeg-chromium` with 157:** there is no `media-video/ffmpeg-chromium-157` yet.
- **USE=bundled-toolchain** (Google's prebuilt clang/Rust) isn't adapted to the 156/157
  changes (e.g. its bundled clang-format is removed but referenced by Crubit). It's
  opt-in and by definition uses prebuilt binaries.
- **gn ebuild:** uses git-r3 (pinned commit). A distfile tarball would need hosting.
- **esbuild / typescript:** use the deprecated `EGO_SUM` for the same reason.
- **pkgcheck** reports a few inherited warnings: `llvm-r1` → `llvm-r2`, the deliberate
  `sys-libs/zlib` dependency (bug #930365), and the size of `files/`.
- **Privacy:** Chromium still talks to Google about non-Google things in the
  background. See `doc/chromium-runtime-downloads.md`; not addressed yet.
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
- **Generated and prebuilt files:** see `doc/chromium-generated-files.md` for what is regenerated,
  rebuilt from source, or used as is, and why.

## More

- **Crubit notes:** see `doc/crubit.md`.
- **New versions:** `scripts/chromium-delta/README.md` describes how upgrade patches are made and
  checked (for a release without a tarball yet, and for later fixes on a release branch), and what
  went wrong before.
