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
3. Google's Linux Stable needs only `amd64`. For Early Stable and the bleeding-edge `_p<N>_pre`
   builds, accept `~amd64` for `www-client/chromium` and the overlay packages they build with (their
   newer versions are `~amd64`). Don't unmask `www-client/chromium`: since
   2026-11-05 (bug #982204), `::gentoo`'s `profiles/package.mask` masks only
   `<www-client/chromium-151.0.7922.169-r1`, and an unmask entry would also override the
   overlay's `profiles/package.mask`, which masks versions with known unfixed vulnerabilities.
   If you added one while `::gentoo` masked every version, remove it after syncing `::gentoo`.
   `LLVM_COMPAT` is 22 only: LLVM 23 means Rust 1.99, which would need a `dev-util/crubit:1.99.0`.
4. `=dev-python/clang-22*`, pulled in automatically, used by V8's build-time
   header parser ("metagen").

### Faster rebuilds (optional)

`CHROMIUM_BUILD_DIR` in `make.conf` keeps the build tree between builds, so that the next build
of the same major version only rebuilds what changed. The eclass expands it with `MAJOR` set to
the major version. Portage expands variables in `make.conf` even single-quoted, so escape the `$`:

```sh
CHROMIUM_BUILD_DIR="/var/tmp/portage/chromium-build/\${MAJOR}"
```

A build unpacks the sources to `src/` and builds them in `build/Release` (`../build/Release` from
the sources), both in its `WORKDIR`, or in this directory with `CHROMIUM_BUILD_DIR`. The kept
tree (tens of GB per major):

```
src/                      the sources: each build unpacks its own, src_install removes them
build/
├── Release/              the build directory (ninja's)
├── StaticRoots/          V8's static-roots build
├── state                 the sources' records: contents (hash) and timestamp at the last ninja run
├── owner                 the build using the tree
├── toolchains            the compilers its objects were built with
└── mojom-message-id-salt
```

Before each ninja run, files whose contents are those of the last run get that run's timestamp
back, so ninja only rebuilds from changed files (`files/chromium-build-tree.py`). ninja doesn't
notice a new compiler version in the same LLVM or Rust slot: the ebuild warns, and deleting
`build/` forces a full build (with new records and a new salt).

With `USE=official`, Chromium scrambles Mojo's message IDs with a salt that is `chrome/VERSION`
upstream, so every version bump regenerates every Mojo binding and recompiles what includes one
(about 3,000 objects). A kept tree uses its own random salt instead, `mojom-message-id-salt`
(created by its first build): the IDs stay the same across the tree's bumps, but can't be
computed from the public sources. Delete the file to get a new salt (and a rebuild of those
objects) on the next build.

The tree's `src/` is emptied at the end of `src_install` (the next build unpacks its own sources
anyway). `CHROMIUM_BUILD_DIR_KEEP_SRC=1` keeps them until the next build, `0` removes them;
unset, `FEATURES=keepwork` keeps them.
`src/` and `build/` can be mount points (e.g. `src/` on tmpfs, `build/` on a disk).

A second build of the same major waits until the first is done (until its Portage build
directory is unlocked). Running the first one's phases as separate `ebuild` commands unlocks it
between them, so a waiting build can take the tree before the first one's `install`.

## Notable ebuild changes vs. 151

- **Gentoo patchset:** forked from `chromium-patches` tag 152 into
  `files/chromium-patches-156/` (now `files/chromium-patches-157/` and `-158/`; 156 was dropped on
  2026-11-03).
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
- **`chromium-157-no-runtime-executable-downloads.patch`** (first made for 156): Chromium never downloads or
  loads code via the component updater: Widevine CDM, Screen AI, SODA, TranslateKit, the
  WASM TTS engine, component-extension JavaScript, the Commerce Heuristics component (its
  archive carries a JavaScript file), and the remote DevTools front-end.
  - Code downloaded by an *earlier* build in the same profile isn't loaded either (Widevine
    hint file, stored TranslateKit and SODA paths; a Screen AI copy is deleted).
  - With `USE=widevine`, a CDM installed next to the browser (`/usr/lib64/chromium-browser/WidevineCdm`,
    e.g. from `www-plugins/chrome-binary-plugins`) is used directly. This is compile-tested, but not
    runtime-tested.
  - The Translator web API reports "unavailable" rather than hanging. The DevTools CSP no longer allows
    remote scripts.
  - Data components (CRLSet, filter lists, hints, …) are unaffected.
- **`chromium-157-system-crubit.patch`** (first made for 156): lets Chromium's GN use a system Crubit with the
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
- **`chromium-157-v8-metagen-resource-dir.patch`** (first made for 156) plus GN args: V8 metagen uses the
  system libclang instead of a prebuilt one.
- **Unused npm packages are deleted** (`files/chromium-prune-node-modules.py`, keep list
  `files/chromium-<major>-node-modules.txt`): 144 of the tarball's 1329 packages (372 MiB, mostly
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
    DrumBrake didn't build in 156 as is: `chromium-156-hardened-v8-drumbrake-declares-locals.patch`
    (dropped with 156) added a method V8's debugger interface gained but the interpreter's scope iterator lacks.
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

Also new, for 156: `chromium-156-disable-tos-dialog.patch` (from ungoogled-chromium; dropped with 156)
skipped the built-in terms dialog Linux builds show on a new profile's first run (157 does the same
upstream).

`chromium-156-crash-bubble-once.patch` fixes an upstream bug: after a crash and a restore from
the "Restore pages?" bubble, a window opened later through the startup path (running `chromium`
again, a launcher) offered to restore again. `HasPendingUncleanExit()` relied on
`ProfileLaunchObserver`, which forgets the launched profiles once startup is done; it now also
requires `ExitTypeService` to still be waiting for the user to acknowledge the crash.

`chromium-157-glic-extension-needs-glic.patch` (157 and 158): upstream loads Glic's bundled extension
whenever `kApiGlicPrivate` is on (the default), although Glic itself is off on Linux; the extension accepts
messages from pages on `gemini.google.com` and `*.google.com` (its state, `invoke`, `activateTab`, …). It
now loads only when Glic is enabled too (`chrome://flags/#glic`), as upstream then.

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

## 158

The 158 ebuilds (`158.0.8127.18`, Google's Early Stable: `SLOT="stable"`, and the bleeding-edge
`158.0.8127.39_p<N>_pre`, built from its tarball and upgrade patches) are the 157 one with these
differences:
- No Crubit patch: 158 supports a system Crubit itself (its `rust_crubit_root` GN argument, and
  C++ bindings of the prebuilt stdlib from its `.rmeta` files), which the ebuild says with
  `CHROMIUM_UPSTREAM_CRUBIT`. 158 lists fewer crates of the prebuilt stdlib than Rust 1.98's
  std links (its list follows its own, newer Rust): `CHROMIUM_RUST_STDLIB_ADDED` adds
  `addr2line`, `adler2`, `gimli` and `miniz_oxide` back.
- Patches rebased for 158: `chromium-158-no-runtime-executable-downloads.patch` (AIM
  Eligibility's installer became `component_extension_installer.cc`, which also registers a new
  New Tab Page component extension: both uninstalled; Screen AI's gate and the DevTools remote
  front-end's host changed), and the Gentoo patchset as `files/chromium-patches-158/`
  (`cr149-bindgen-libclang-paths` rebased, `cr152-fix-rust-2-oxidize-harder` reduced to
  clippy-driver's path, `cr149-fix-rust` dropped: 158 does both itself).
- New patches: `chromium-158-abseil-gn-no-strict-includes.patch` (abseil's BUILD.gn converter
  would write an enum the pinned gn doesn't know, and that upstream's checked-in files don't
  have) and, with `USE=hardened`, `chromium-158-hardened-v8-drumbrake-build-fixes.patch` (V8
  main's fixes for its WebAssembly interpreter, which doesn't build in V8 158).
- Dropped: the BoringSSL curve25519 tables script patch (BoringSSL updated the script).
- Layout: `third_party/khronos` and `third_party/libsecret` are gone (`CHROMIUM_KEEPLIBS_DROP`);
  pdfium's OpenJPEG and libtiff sources are in `src/` (`CHROMIUM_PDFIUM_SRC_SUBDIR`); V8's static
  roots are in `src/gen/intl-wasm/`. V8 158 can use checked-in copies of a few generated headers
  (`src/gen/intl-wasm`); the ebuild generates them (`v8_use_checked_in_generated_headers=false`).
  `tools/typescript/definitions/wallpaper.d.ts` is kept as source: 158 removed its schema.
  `third_party/oak/src/oak_session/tls` is kept as a bundled source (158 builds it).
- Newer pins: gn 0.2603 (158's `.gn` sets `check_includes_strict_exceptions`), Crubit 20261015,
  Vulkan-Headers v1.4.366 (Vulkan-Docs at its tag), Wuffs 0.3.6, copium 84aa29c73d11, and
  chromium-bidi's new autofill-event spec. `dev-util/chromium-node-modules:158`: puppeteer-core
  25.16.0 (its devtools-protocol types are made with Chromium's generator, where it moved), and
  WebUI's lit cache directive. `dev-util/chromium-rust-crates:158`: ICU4X 2.4.0 (CLDR 49.0.0,
  ICU export data 79.1rc, Unicode 18.0.0's character data), with the new
  `icu_locale_fallback_data`. `dev-util/gnrt:158` (its new `replace_with`).

Built offline with `USE=hardened` and runtime-tested like 157 (components, DevTools, WebDriver
BiDi, WebGL, "Restore pages?"): the same results, but for the components list (158 drops Related
Website Sets and adds an optimization guide model). The same 28 checked-in generated files as 157's
are not made again (unused: ANGLE's unused Vulkan shader variants, codemirror.next's stale chunks,
OpenXR's with `USE=-openxr`, XNNPACK's RISC-V kernels).

## Known issues / TODO

- **`USE=system-icu` doesn't work, and the overlay masks it** (`profiles/package.use.mask`, as
  `::gentoo`'s `profiles/base/package.use.mask` did, bug #943216), so builds use the bundled ICU, as
  with 151. The next ebuilds drop the flag. Unmasking it locally shows three blockers:
  1. ICU ≥ 76's C++ API uses `std::u16string_view`, which doesn't link against Chromium's own
     libc++ (`std::__Cr`), and the ebuild requires that libc++.
  2. V8's Temporal code includes ICU-internal headers (`udatamem.h`) that system ICU doesn't install.
  3. Build-time generators expect `icudtl.dat`. A GN fix for this one is shelved, since it doesn't help
     without the other two.
- **`USE=ffmpeg-chromium`** hasn't been tested with this overlay's builds (`::gentoo` added
  `media-video/ffmpeg-chromium:157` and `:158` on 2026-11-11).
- **USE=bundled-toolchain** (Google's prebuilt clang/Rust) isn't adapted to the 156/157
  changes (e.g. its bundled clang-format is removed but referenced by Crubit). It's
  opt-in and by definition uses prebuilt binaries.
- **gn ebuild:** uses git-r3 (pinned commit). A distfile tarball would need hosting.
- **esbuild / typescript:** use the deprecated `EGO_SUM` for the same reason.
- **pkgcheck** reports a few inherited warnings: the deliberate `sys-libs/zlib` dependency
  (bug #930365) and the size of `files/` (with a `::gentoo` older than 2026-11-09, also
  `llvm-r1` → `llvm-r2`: the eclass takes whichever LLVM eclass `rust.eclass` inherits).
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
- **protoc starts from upstream's generated code.** protoc is compiled from the C++ code
  generated from its own protos (`descriptor.proto`, `plugin.proto` and the feature protos), so
  the first protoc of each build is built from the copies upstream generated and ships in the
  tarball. The build regenerates them with it, rebuilds protoc from the regenerated ones, and
  checks that this protoc regenerates them unchanged: everything the build uses is made by this
  protoc, or is identical to what it makes. But the chain still starts from upstream's output,
  which is trusted: that needs fixing. A fix needs a first protoc (or a generator of
  those files) that doesn't come from generated code.
- **Generated and prebuilt files:** see `doc/chromium-generated-files.md` for what is regenerated,
  rebuilt from source, or used as is, and why.

## More

- **Crubit notes:** see `doc/crubit.md`.
- **New versions:** `scripts/chromium-delta/README.md` describes how upgrade patches are made and
  checked (for a release without a tarball yet, and for later fixes on a release branch), and what
  went wrong before.
