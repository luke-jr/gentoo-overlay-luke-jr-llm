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
| `dev-lang/typescript:7.0.2` | TypeScript 7 (the Go compiler, `tsgo`) built from source, slotted per exact version beside `::gentoo`'s TypeScript 6. Upstream compiles all WebUI/DevTools TypeScript with a prebuilt `tsgo`. The output was verified byte-identical to upstream's binary across all ~17k TypeScript outputs. |
| `dev-lang/rustc-dev:1.98.1` | The Rust compiler's own crates (the `rustc-dev` component, what `rustup component add rustc-dev` installs), from the tarball `dev-lang/rust` builds with `USE=dist`, installed into that Rust slot's sysroot. Crubit links against them. |
| `dev-util/crubit:1.98.1` | Crubit's `cc_bindings_from_rs`, built from source against the selected `dev-lang/rust`. Since M153–156, default-on code (Blink's FontFormatCheck, the Web Bundle parser, …) is Rust that C++ reaches only through Crubit-generated bindings. |
| `dev-util/rollup:4.21.0` | The Rollup bundler built from source: its CLI (rollup's TypeScript plus the 17 npm packages its own build bundles in, each from its source, bundled with esbuild) and its JavaScript parser (Rust) as a native Node.js addon. Replaces `@rollup/wasm-node` (generated JavaScript and a prebuilt WebAssembly parser), used for WebUI bundling; chromium-bidi's own (newer) copy is replaced by the same one. WebUI bundles are byte-identical to the npm package's; the BiDi mapper only keeps a little more dead code. Replaces `dev-util/rollup-native` (parser only). |
| `dev-util/chromium-node-modules:156` | Generated files of the npm packages in Chromium's tarball, built from the packages' git sources as self-contained esbuild bundles, installed at the paths of the files they replace (Chromium copies them over, after checking versions). So far: terser's library bundle (WebUI/Mojo minification), chromium-bidi's three rollup plugins (node-resolve, cleanup, license; 31 packages from source, incl. moment and lodash) and WebUI's `postcss-selector-parser`. Build outputs are byte-identical. |
| `media-video/ffmpeg-chromium-156` | for `USE=ffmpeg-chromium` (`::gentoo` stops at 154) |

All except `ffmpeg-chromium` are **build-time only** (`BDEPEND`) for Chromium. `ffmpeg-chromium` is a runtime
dependency, and only with `USE=ffmpeg-chromium`; it builds and installs, but hasn't been tested in use.

Everything is keyworded `~amd64 ~arm64`. Only amd64 has been built and tested.

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
   builds the `rustc-dev` component, which `dev-lang/rustc-dev:1.98.1` installs and Crubit
   builds against. Both must match *this* Rust build: they use its exact
   `librustc_driver-<hash>.so`. Rebuilding Rust means rebuilding `dev-lang/rustc-dev:1.98.1`
   and `dev-util/crubit:1.98.1` (the Chromium ebuild checks the latter).
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
- **Unused npm packages are deleted** (`files/chromium-prune-node-modules.py`, keep list
  `files/chromium-156-node-modules.txt`): 148 of the tarball's 1329 packages (372 MiB, mostly
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

No USE flags were removed.

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
  148 remain. Rollup, terser, chromium-bidi's rollup plugins and WebUI's CSS minifier now use
  files built from source (`dev-util/rollup`, `dev-util/chromium-node-modules`). Of the rest, 64
  are hand-written source identical to their git tags, 36 only provide type declarations, and
  some are data (caniuse, MDN, SPDX lists). Still generated, roughly in order of effort:
  - ts-proto (protoc plugin for TypeScript; ts-proto-descriptors is ts-proto's own output);
  - DevTools' postcss/cssnano/svgo (CSS minification, SVG optimization);
  - `lit`/`lit-html`/`lit-element`, which ship in WebUI: build from their TypeScript sources;
  - the `typescript` package that DevTools' `collect-ui-strings` uses, ts-proto, small DevTools helpers;
  - DevTools' vendored `front_end/third_party` (~7 MB, mostly checked-in build output: Lighthouse,
    CodeMirror, Puppeteer, ...), which ships in the browser.
- **Crubit notes:** see `NOTES-crubit.md`.
- **Metadata:** no package lists a maintainer: the `::gentoo` ones' Gentoo maintainers were removed, since
  they don't maintain this overlay. Add yourself if you like. The generated AppStream data uses upstream
  Chromium's contact and bug-report URL instead of Gentoo's. `metadata/md5-cache` isn't tracked in git; Portage
  regenerates it (or run `egencache`).
