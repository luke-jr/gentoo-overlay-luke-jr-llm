# luke-jr-llm

> **Use at your own risk.** This overlay is maintained by an LLM (Claude), with only human
> direction. No human has fully reviewed it: not a Gentoo developer, not anyone else, not even the
> person directing it. It is not an official Gentoo repository. It patches and rebuilds a web
> browser, which is security-sensitive software; its changes may have bugs that upstream Chromium or
> `::gentoo` don't. Only amd64 has been built and tested, on one machine's configuration. There is
> no warranty of any kind (see the GPL-2 the ebuilds are distributed under). Read what an ebuild
> does before you build it.

Gentoo overlay (repository name `luke-jr-llm`): currently Chromium, built entirely from source, and
the tools that build needs. Example `/etc/portage/repos.conf/luke-jr-llm.conf`:

```ini
[luke-jr-llm]
location = /var/db/repos/luke-jr-llm
masters = gentoo
auto-sync = no
```

`www-client/chromium-156.0.8078.83_pre`, `157.0.8103.33_pre-r6` and `157.0.8103.15`, based on `::gentoo`'s
`chromium-151.0.7922.169-r1` (`::gentoo` has masked Chromium for removal on 2026-10-24, bug #982204).
All are built from Google's official "lite" source tarballs.

See `doc/chromium.md`.

## Rules

What the packages here follow, beyond Gentoo's own policies:

- **No prebuilt binaries.** Everything is built from source; no bundled or third-party compiled code
  is used, and the ebuilds delete what the source tarballs ship (and die if any is left). The only
  exceptions are opt-in USE flags that say so (e.g. Chromium's `bundled-toolchain`).
- **No executable code downloaded at runtime**, apart from the JavaScript and WebAssembly that web
  pages themselves load. Data downloads (lists, dictionaries, certificates) are fine.
- **Generated files are regenerated.** A checked-in generated file is not a source: it is made again
  from its inputs with its upstream generator, or replaced by one built here, and the checked-in copy
  is moved aside so the build cannot use it. Prebuilt JavaScript (minified, bundled or compiled) counts
  as generated. What stays as is, and why, is documented per package. Output identical to upstream's
  is a check that the regeneration is faithful, not a goal in itself.
- **Builds are offline.** Everything comes from `SRC_URI`, at the revisions upstream pins.
- **Ebuild phases:** `src_prepare` only applies patches and copies in files from installed packages;
  generating happens in `src_configure` (files the build configuration reads) or `src_compile`.
- **Your flags are used.** Tools built and run during the build are compiled with your own compiler and
  flags (GCC unless your configuration says otherwise), filtered only where clang rejects them
  (`strip-unsupported-flags`). The package's own code uses the compiler and flags its upstream build
  uses, as before.
- **Upstream behaviour and features stay** unless a rule above needs a change (Chromium's omnibox **AI
  Mode** button stays, for example). USE flags are not removed; build-only tools are `BDEPEND`.

## Packages

| Package | Why |
|---|---|
| `www-client/chromium-156.0.8078.83_pre` | the browser: 156.0.8078.83, the newest tag of the 156 branch, which has no release or source tarball: built from Google's official "lite" tarball of 156.0.8078.79 (Linux Stable) plus `files/chromium-156.0.8078.79-to-156.0.8078.83.patch` (the upstream changes that can affect a Linux build; see its header), and the CVE-2026-110914 fix 156 hasn't got yet. `_pre` sorts below a real 156.0.8078.83 release, which replaces it. |
| `www-client/chromium-157.0.8103.33_pre-r6` | the browser: 157.0.8103.33, the newest tag of the 157 branch, which has no source tarball: built from Google's official "lite" tarball of 157.0.8103.30 plus `files/chromium-157.0.8103.30-to-157.0.8103.33.patch` (see its header), and the fixes 156 has that 157 hasn't got yet: CVE-2026-76026, CVE-2026-119270, an SVGImage lifetime fix, a Skia heap out-of-bounds write fix, and the media controls, display lock, ~/.cache blocklist, encoding detection, paste sanitization, V8 JSGetTemplateObject, WebRTC EmptyNetworkManager and Length GC fixes merged after .33 (see their headers). 157 is Google's early stable release (Windows and Mac only so far), so `SLOT="stable"` with `~amd64`: it replaces 156 for `~amd64` users, and becomes `amd64` when Google releases 157 for Linux Stable. |
| `www-client/chromium-157.0.8103.15` | the browser: 157.0.8103.15, **Beta** on Linux (Google's early stable release of it is for Windows and Mac only), so `SLOT="beta"`, as `::gentoo` slots channels: it installs beside stable as `chromium-browser-beta`, with its own profile directory. Built from Google's official "lite" source tarball (it already has the CVE-2026-110914 fix), plus the CVE-2026-118332 fix 157 hasn't got yet. See "157" below for how it differs from 156. |
| `dev-util/ragel-6.10:6` | Ragel 6 in slot 6, installed as `ragel-6`, for systems that keep `::gentoo`'s Ragel 7 (`::gentoo` has 6 and 7 both in slot 0). Chromium's ebuild regenerates HarfBuzz's state machines with Ragel 6 (HarfBuzz requires 6.10): `::gentoo`'s `dev-util/ragel-6.10` when that is installed or nothing is, this slot when Ragel 7 is installed. |
| `dev-util/esbuild-0.28.2` | DevTools needs exactly this version. `::gentoo` stops at 0.27.3, and deps.gentoo.zip has no vendor tarball, so this uses `EGO_SUM`. |
| `dev-build/gn-0.2578`, `gn-0.2595` | 156's `.gn` needs gn ≥ 1b0f22ec, 157's needs 0.2595. Pinned to the commits Chromium's `DEPS` uses, via git-r3, because there is no tarball and gitiles archives aren't reproducible. |
| `dev-lang/typescript:6.0.2` | TypeScript 6 (the JavaScript implementation: compiler, language server, JavaScript API) built from source the way upstream builds its npm package; `::gentoo`'s `dev-lang/typescript` installs the npm package's prebuilt bundles. DevTools' build uses its JavaScript API (`collect-ui-strings`). `lib*.d.ts`, `typesMap.json` and the localized messages are byte-identical to npm's; `typescript.d.ts` differs in formatting only (upstream formats it with dprint's prebuilt WebAssembly plugin). |
| `dev-lang/typescript:7.0.2` | TypeScript 7 (the Go compiler, `tsgo`) built from source, slotted per exact version beside `::gentoo`'s TypeScript 6. Upstream compiles all WebUI/DevTools TypeScript with a prebuilt `tsgo`. The output was verified byte-identical to upstream's binary across all ~17k TypeScript outputs. |
| `dev-util/crubit-1.98.1_p20260908`, `_p20260930` | One slot per version: each Chromium major pins its own Crubit commit (`CRUBIT_DATE`; 156: 20260908, 157: 20260930), built against Rust 1.98.1. Crubit's `cc_bindings_from_rs`, built from source against the selected `dev-lang/rust`. It links the compiler's own crates (the `rustc-dev` component), which it unpacks at build time from the tarball `dev-lang/rust` builds with `USE=dist`; nothing extra is installed. Since M153–156, default-on code (Blink's FontFormatCheck, the Web Bundle parser, …) is Rust that C++ reaches only through Crubit-generated bindings. |
| `dev-util/rollup:4.21.0` | The Rollup bundler built from source: its CLI (rollup's TypeScript plus the 17 npm packages its own build bundles in, each from its source, bundled with esbuild) and its JavaScript parser (Rust) as a native Node.js addon. Replaces `@rollup/wasm-node` (generated JavaScript and a prebuilt WebAssembly parser), used for WebUI bundling; chromium-bidi's own (newer) copy is replaced by the same one. WebUI bundles are byte-identical to the npm package's; the BiDi mapper only keeps a little more dead code. |
| `dev-util/chromium-node-modules:156`, `:157` | Generated files of the npm packages in Chromium's tarball and of the JavaScript libraries DevTools vendors, built from the packages' git sources, installed at the paths of the files they replace (`tree/`; Chromium copies them over, after checking versions in `VERSIONS`) or as inputs for Chromium's own rebuild steps (`build/`). Built once per Chromium major version. Build tools: terser (WebUI/Mojo minification), chromium-bidi's three rollup plugins (31 packages, incl. moment and lodash), WebUI's `postcss-selector-parser`, ts-proto's protoc plugin (bootstrapped: its committed, self-generated descriptors are regenerated and must reach a fixpoint), DevTools' build tools (cssnano's and svgo's generated packages, yargs and its family, js-yaml, uuid, esbuild's JavaScript API). Shipped code: zod and mitt (BiDi mapper), `@bufbuild/protobuf`'s ES modules, WebUI's lit and DevTools' lit (with lit's own rollup configs), and DevTools' acorn, CodeMirror 5 runmode, `diff_match_patch`, intl-messageformat, json5, marked, wasmparser, Puppeteer and Puppeteer Replay (with mitt, parsel, rxjs, urlpattern-polyfill), the 41 packages of `codemirror.next` (Lezer parsers regenerated from their grammars), and Lighthouse 13.5.0 (`lighthouse-dt-bundle.js`, the report renderer and generator, legacy-javascript) with the ~40 npm packages its build bundles and axe-core 4.13.0 (Lighthouse's accessibility engine, with the ~25 packages it bundles; emoji-regex's pattern made from Unicode's `emoji-test.txt`). |
| `dev-util/gnrt:156`, `:157` | Chromium's own `gnrt` (`tools/crates/gnrt`), which writes the `BUILD.gn` files of the vendored Rust crates; the Chromium ebuild runs `gnrt gen` instead of using the checked-in ones (all 269 come out byte-identical). Built from the Chromium tarball (only that directory is unpacked) without its crate downloader (`files/gnrt-156-no-download.patch`), which drops 137 of its 268 crates (HTTP, TLS). |
| `dev-util/chromium-rust-crates:156`, `:157` | The generated code and data of the vendored Rust crates, regenerated with their upstream generators at the commits the crates were published from, and installed at the paths of the files they replace (Chromium copies them over, after checking versions). syn's visitors, the Unicode tables of regex-syntax (ucd-generate), unicode-ident and unicode-width, RustFFT's SIMD butterflies, fontations' table code (read-fonts, write-fonts, skrifa), ICU4X's baked data and `icu_capi`'s generated FFI code, temporal_rs' time zone data and `zoneinfo64.res` (ICU's `genrb`). The generators' 229 crates are fetched; the rest of their lockfiles are stubs. |
| `dev-util/cddlconv` (slots `0.1.7`, `0.1.10`, `0.1.12`, `0.2.0`) | The CDDL-to-TypeScript/Zod converter from the WebDriver BiDi tooling, built from source, one slot per version: chromium-bidi's protocol types (156: 0.1.12, 157: 0.2.0) and the `webdriver-bidi-protocol` types in `chromium-node-modules` (156: 0.1.7, 157: 0.1.10) are each regenerated with the version that made them. |
| `media-video/ffmpeg-chromium-156` | for `USE=ffmpeg-chromium` with Chromium 156 (`::gentoo` stops at 154; there is no 157 yet) |

All except `ffmpeg-chromium` are **build-time only** (`BDEPEND`) for Chromium. `ffmpeg-chromium` is a runtime
dependency, and only with `USE=ffmpeg-chromium`; it builds and installs, but hasn't been tested in use.

Everything is keyworded `~amd64 ~arm64`, except the Chromium version Google releases as Stable for
Linux, which is `amd64` (see `doc/chromium-maintenance.md`). Only amd64 has been built and tested.

`eclass/chromium-llm.eclass` is the Chromium build, shared by the `www-client/chromium` ebuilds;
each ebuild has only what is particular to its version: upstream's pins, its patch lists and the
fixes it carries. A change to the eclass must not change what the existing ebuilds do
(`scripts/chromium-ebuild-env/` checks that).

`eclass/cargo-stubs.eclass` keeps the Rust packages (`crubit`, `rollup`, `gnrt`, `chromium-rust-crates`) from fetching crates
that Linux never builds (winapi, windows-sys, wasi, …): it writes a stub with the same
name, version, checksum, dependencies and features in their place, which `compile_error!`s if
anything does build it. `scripts/cargo-unused-crates.py` lists the candidates from a `Cargo.lock`.

## Documentation

- `doc/chromium.md`: the Chromium ebuilds: build machine setup, changes from `::gentoo`, the 157
  differences, known issues.
- `doc/chromium-generated-files.md`: what is regenerated, rebuilt from source, or used as is.
- `doc/chromium-maintenance.md`: adding a new Chromium version, and checking it.
- `doc/chromium-runtime-downloads.md`: what Chromium downloads at runtime, and what the ebuild blocks.
- `doc/crubit.md`: notes on Crubit (the C++/Rust bindings generator).
- `scripts/chromium-delta/README.md`: upgrade patches for releases without a tarball yet.
- `scripts/chromium-ebuild-env/README.md`: checking that an eclass change leaves the existing
  ebuilds alone.
- `scripts/chromium-tests/README.md`: checks for a Chromium build.

## Metadata

No package lists a maintainer: the `::gentoo` ones' Gentoo maintainers were removed, since
they don't maintain this overlay. Add yourself if you like. The generated AppStream data uses upstream
Chromium's contact and bug-report URL instead of Gentoo's. `metadata/md5-cache` isn't tracked in git; Portage
regenerates it (or run `egencache`).
