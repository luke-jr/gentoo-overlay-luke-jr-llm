# Crubit (`cpp_api_from_rust`) in Chromium 156 with a system Rust toolchain

Status: analysis done; `dev-util/crubit` draft ebuild written (not emerged).
Source paths are relative to `chromium-156.0.8078.12/` unless noted.
**[V]** means verified (read in source, or tested). **[A]** means assumed.

## TL;DR

* Two Crubit users are active in an upstream default build and have **no
  hand-written C++/cxx path in 156**:
  * `font_format_bindings`: every web font goes through it.
  * `web_package_rust_bindings`: the Web Bundle parser, which `<script type="webbundle">` uses by default.

  Under "match upstream defaults", Crubit is therefore **required**.
* Once Crubit is available, setting `enable_cpp_api_from_rust=true` puts *every*
  user on exactly the upstream configuration. That means no stubs, no reverts, and CBOR, PVT and IFT
  stay compiled in but disabled by their features, as upstream has them.
* **Rust side [V]:**
  * Rust 1.98.1 `x.py dist` always produces a `rustc-dev` tarball (`RustcDev` is a
    default dist step regardless of `extended`/`tools`), so `dev-lang/rust[dist]`
    is enough. It's a USE flag only, with no change to the rust ebuild.
  * Crubit at Chromium 156's `CRUBIT_REVISION` (a355b02, 2026-09-08)
    **compiles unmodified with stable 1.98.1 + `RUSTC_BOOTSTRAP=1`**. I tested this with
    the official 1.98.1 rustc+rustc-dev.
  * Std bindings can be generated from a **prebuilt** std via Crubit's rmeta mode. I tested
    end to end: bindings were generated, the Rust thunks and C++ headers compiled, and the result linked and ran.
* **Chromium side:** needs a moderate GN patch. The new part is std bindings from the
  prebuilt sysroot (≈150 lines GN+py) plus a handful of path/condition tweaks. This part is not
  tested in GN yet.

## Deliverable A: the Crubit users

| Target | What | Upstream default | Non-Crubit path in 156 | Class |
|---|---|---|---|---|
| `components/cbor/rust:cbor_rust_bindings` | Rust CBOR reader/writer behind `cbor::Reader/Writer` | compiled in, **off**: `kUseRustCborParser`/`Writer` `FEATURE_DISABLED_BY_DEFAULT` (reader.cc:50, writer.cc:30); Finch trial only (fieldtrial_testing_config.json:19088,19110) | **yes**: hand-written C++ reader/writer; buildflag `USE_CBOR_RUST` (cbor/BUILD.gn:15) + runtime feature | **1** |
| `components/private_verification_tokens/common/athm_ffi:athm_ffi_bindings` | Private Verification Tokens (Privacy Pass ATHM; Google-issued anti-fraud tokens via component updater) | **off**: `net::features::kEnablePrivateVerificationTokens` DISABLED (net/base/features.cc:981); no Finch config, no chrome://flags | no (born on Crubit in M154). Stub or PF4's removal patch | **1** |
| `third_party/blink/.../fonts:ift_patcher_bindings` | Incremental Font Transfer patcher (W3C IFT) | **off**: `IncrementalFontTransfer` `status: "test"` (runtime_enabled_features.json5:3722) → generated base::Feature DISABLED; `IftPatcher::Create` returns nullptr (ift/ift_patcher.cc:64) | no (born on Crubit in M155). Stub `Create()` → nullptr | **1** |
| `components/web_package/signed_web_bundles/rust:signed_web_bundles_rust_bindings` | Signed Web Bundle integrity-block parsing, Ed25519/ECDSA-P256 verify, SHA-512 (Isolated Web Apps) | **off on Linux**: `kIsolatedWebApps` enabled only on ChromeOS (content/public/common/content_features.cc:655-660); available in chrome://flags (about_flags.cc:5880-5883) | **no** in 156; C++ existed ≤M153 (PF4 `chromium-154-cbor-fix.patch` restores it) | **1** (functionally), but needs a revert or IWA stub to link without Crubit |
| `components/web_package/rust:web_package_rust_bindings` | Web Bundle (.wbn) parser `web_package::WebBundleParser` | **on**: subresource web bundles (`<script type="webbundle">`, script_loader.cc:477, ungated) → network service instantiates the parser directly (services/network/web_bundle/web_bundle_url_loader_factory.cc:600); also IWAs via data_decoder | **no**: migrated in M156 (5 commits, see below); 994-line C++ parser in ≤M155 | **2** |
| `third_party/blink/.../fonts:font_format_bindings` | `FontFormatCheck`: classifies every web font (variable/COLRv0/v1/CBDT/sbix/CFF2/avar2) to pick FreeType vs Fontations | **on**: always (web_font_typeface_factory.cc:130-181, font_custom_platform_data.cc:127) | **no**: C++ (HarfBuzz) ≤M140, Rust via **cxx** M141-M152, Crubit since **M153** | **2** |
| `third_party/rust/qr_code/v2:cpp_api_from_rust` | QR generator ("Create QR code") | on; upstream uses the Crubit path | **yes**: hand-written cxx glue `qr_code_generator_ffi_glue.rs`, auto-selected by `enable_cpp_api_from_rust` (components/qr_code_generator/BUILD.gn:36-79) | 1 (follows Crubit automatically if enabled) |

Notes per user:

* **CBOR.**
  * Stubbing means flipping `USE_CBOR_RUST` to `$enable_cpp_api_from_rust` and gating the
    two deps. PF4's patch does exactly this.
  * We'd lose only the possibility of enabling the Rust parser via
    `--enable-features`. The Gentoo ebuild sets `disable_fieldtrial_testing_config=true` (ebuild:1274) anyway.
  * The Rust `cbor` crate itself is still built, because web_package uses it from Rust. Only the
    bindings need Crubit.
* **font_format.**
  * Switch history:
    * C++ (`hb_face_reference_table`) through M140.
    * Rust read-fonts with a `#[cxx::bridge]` in M141-M152: 152's `format_check.rs` has the bridge and the `.cc` includes `format_check.rs.h`.
    * M153 added `fonts/BUILD.gn` with `cpp_api_from_rust`.
  * Reverting to cxx is small: restore the bridge block, `Box<FontFormatInfo>`, and the `rust::Box` member in the
    header, about 60 lines. PF4 does this in 154. 156's `is_avar2` change (`major >= 2`, crbug 513446410) must be kept.
  * This is still a deviation from upstream in default-active code.
* **web_package.**
  * 156 migrated the parser in 5 commits on 2026-09-15:
    * 3acae5c2d3 (+189/-22)
    * f9482454ab (+320/-115)
    * 1229ce5bd1 (+327/-132)
    * 5884c13c7d (+298/-158)
    * f168635763 (+925/-178)
  * Related commits: 185f0c1d68 removed InputReader (-308), and 45abe2ab63 (BUILD.gn split).
  * Signed bundles moved earlier: e85da0b2f2 (+873/-165, integrity block parser) and b2c9d9c61c (+147/-69,
    signature verifier), plus the M154 Ed25519/ECDSA/utils changes that PF4 reverts.
  * Reverting means re-introducing a C++ CBOR/bundle parser on untrusted input
    that upstream deliberately replaced, and maintaining roughly 3k lines of reverts per milestone.
* **PF4 for comparison** (PF4 tops out at 154):
  * `chromium-154-cbor-fix.patch` = CBOR buildflag gating + revert of the M154 signed-web-bundle Rust code to the old C++ (BoringSSL `ED25519_verify`, `crypto::sign` ECDSA, `cbor::Writer`, `crypto::hash` SHA-512) + font_format back to cxx.
  * With it, web bundles and IWAs work as they did in ≤153.
  * `chromium-154-private_verification_tokens.patch` removes the PVT feature entirely (295 lines).
* **No production use of `rs_bindings_from_cc`** in 156 [V]. Only `build/rust/tests/*` reference it,
  and `build_crubit.py` builds only `cc_bindings_from_rs` (`CRUBIT_BINS`). M157 starts building `rs_bindings_from_cc`
  (`ENABLE_BUILDING_RS_BINDINGS_FROM_CC=True`, which needs LLVM/Clang, Abseil and Protobuf). copium's `cr157-crubit-fix-rs_bindings_from_cc-breakages.patch`
  turns it back off; "nothing in Chromium uses rs_bindings_from_cc yet".

**Verdict:** category-2 users exist (font_format, web_package_rust), so we use Crubit. With Crubit,
every user above simply follows upstream.

## Deliverable B: Crubit as a separate package

### B1. rustc-dev from Gentoo dev-lang/rust 1.98.1, USE=dist [V]

* **Dist step (1.98.1 `src/bootstrap/src/core/build_steps/dist.rs`):**
  * `RustcDev::is_default_step` returns `true` unconditionally (901-969, default at 927-929). It is skipped only
    for non-build hosts (`skip_host_target_lib`, 766-775).
  * `extended`/`tools` only gate extended tools (`should_build_extended_tool`, 55-60).
  * So the ebuild's `x.py dist` (rust-1.98.1.ebuild:969-974, after `x.py install` at :878, same `bootstrap.toml` with `extended = true` at :600 and `tools=[...]` at :601) emits `build/dist/rustc-dev-1.98.1-x86_64-unknown-linux-gnu.tar.xz`, installed to `/usr/lib/rust/1.98.1/dist/`.
* **Same build?**
  * RustcDev ensures `compile::Rustc(stage1→target)`, the same cached step that produced the installed compiler. It then copies that step's stamp (librustc_driver-HASH.so + rustc_* rmeta) via `copy_target_libs` (811-833).
  * Since dist runs in the same build dir right after install, the files are the same [V by code; not empirically]. Gentoo's driver is `librustc_driver-b8bf03664f627b44.so`; official 1.98.1's is `-eaf3ed1d23ca5027`.
  * The official rustc-dev therefore **cannot** be used with Gentoo's rustc (the version string also differs: "(gentoo)").
  * The draft ebuild checks that the tarball's driver hash exists under `/usr/lib/rust/<slot>/lib/` and dies otherwise.
* **Other routes:**
  * `x.py install` also has a `RustcDev` install step, gated on `"rustc-dev"` in `tools` (install.rs:173-178, 282-291). Gentoo's `tools` list doesn't include it.
  * A cleaner long-term option is a Gentoo `USE=rustc-dev` (installs into the slot). A user-side alternative with no ebuild edit is an `/etc/portage/env` `post_src_configure` hook that adds `"rustc-dev"` to `tools`.
* **Cost of USE=dist:**
  * Rust rebuild, plus the time to `x.py dist` and compress.
  * Several hundred MB of tarballs on the *build* machine (rustc-dev xz ≈121 MB, ≈630 MB unpacked).
  * USE=dist also produces rust-src (it vendors library deps) and the combined installer [A: works offline like USE=rust-src].

### B2. How Chromium builds Crubit [V]

* `tools/rust/update_rust.py:48` pins `CRUBIT_REVISION = a355b02da81b…` (google/crubit, 2026-09-08). `build_rust.py --build-crubit` (1185-1193) runs `build_crubit.py` after building rustc.
* What `build_crubit.py` does:
  * `cargo build --release --locked -p cc_bindings_from_rs --bin cc_bindings_from_rs` against the root workspace `Cargo.toml` (`BuildCrubitBinaries`).
  * Adds rpath flags `-Wl,-z,origin -Wl,-rpath,$ORIGIN/../lib` to find librustc_driver.
  * No LLVM/Clang libs (rs_bindings_from_cc is not built).
  * Installs `bin/cc_bindings_from_rs` + `lib/third_party/crubit/{BUILD.gn,LICENSE,crubit.gni,support}` into the toolchain dir (`InstallCrubit`).
* Chromium's toolchain is nightly, so it needs no `RUSTC_BOOTSTRAP`. With stable we need `RUSTC_BOOTSTRAP=1`. Crubit's `rust-toolchain.toml` (nightly + rustc-dev) is ignored without rustup.
* `Cargo.lock` has 181 packages: 82 from crates.io, the rest workspace paths, no git sources.
  * `cc_bindings_from_rs` compiles 42 of them (clap, syn 2+3, proc-macro2, quote, regex, serde/serde_json, phf, itertools, rustversion, …).
  * Offline cargo still needs **all 82** in the directory source. I tested this: with only 42, it errors `no matching package named googletest`. So `CRATES` lists all 82.
* **Test build** (scratch, official 1.98.1 rustc+rust-std+cargo+rustc-dev, `RUSTC_BOOTSTRAP=1`): all crates compile; only libLLVM search-path tweaks were needed for the official tarball layout. The final crates took 31 s with -j8.
  * The binary's only Rust dynamic dependency is `librustc_driver-<hash>.so`. That is the ABI pin.
  * So **no source patches are needed for 156/1.98.1**.
  * Future CRUBIT_REVISIONs may need rustversion/API backports for stable, as copium's `cbit152-rust-1.97-*.patch` did for 152.
* **Functional test** [V] (scratch `t1`, `t2`):
  * Generated `rs_core/rs_alloc/rs_std` bindings in **rmeta mode** from the prebuilt sysroot. Needs `--extern core=…/libcore-*.rmeta`: since 1.98 the std `.rlib`s are metadata stubs.
  * Generated `components/cbor/rust` bindings in rs mode (exactly the flags `cpp_api_from_rust.gni` passes).
  * Compiled the Rust thunk crates (std thunks need support crates `bridge_rust`/`hash_rust`) and compiled the C++ against `support/`.
  * Linked and ran a C++ `cbor::rust::parse_with_config` call: "parse ok".

### B3. Chromium GN integration (what the ebuild must set/patch)

* **Current state with system Rust:**
  * `rust_sysroot_absolute="$(get_rust_prefix)"` (ebuild:1200) → `use_chromium_rust_toolchain=false` (rust.gni:126).
  * → `rust_prebuilt_stdlib=true` (rust.gni:415-416): Gentoo never builds std from source.
  * → `enable_cpp_api_from_rust=false` (rust.gni:425-426).
  * In prebuilt mode rustc keeps its own default sysroot. `prebuilt_stdlib_sysroot` (std/BUILD.gn:338) is unused, and the renamed rlib copies are linker inputs only.
* **Why upstream ties it to its own toolchain** (cpp_api_from_rust.gni:55, 63, 68):
  * (a) The tool must be the same compiler as rustc. Satisfied by slot-tying plus the hashed librustc_driver link.
  * (b) Std bindings come from `build/rust/std/rules` (std built from source, rs-mode Crubit on core/alloc/std, rules/BUILD.gn:246,1128,3288). Prebuilt std has no such targets.
  * (c) `build_with_chromium` is fine.
* **Building std from source instead (rejected):**
  * Chromium's generated `std/rules/BUILD.gn` pins Chromium-nightly std file lists and vendored versions (e.g. addr2line-0.27.1, gimli-0.34.0, libc-0.2.189, object-0.39.1).
  * 1.98.1's library has addr2line-0.25.1, gimli-0.32.3, libc-0.2.185, object-0.37.3, …
  * It would need gnrt regeneration per Rust version plus USE=rust-src.
* **Proposed patch (sketch, not gn-gen tested):**
  1. **rust.gni.** Add a gn arg `rust_crubit_root = ""` and change the condition to
     `enable_cpp_api_from_rust = enable_rust && build_with_chromium && ((use_chromium_rust_toolchain && !rust_prebuilt_stdlib) || (rust_crubit_root != "" && !toolchain_for_rust_host_build_tools))`.
     This keeps host-build-tools toolchains disabled, like upstream.
  2. **cpp_api_from_rust.gni:**
     * Relax the asserts at :55/:63 for that case.
     * Tool path `$rust_crubit_root/bin/cc_bindings_from_rs` (:102).
     * rustfmt `$rust_sysroot/bin/rustfmt` (:104; use the slot-suffixed name as the ebuild already does for bindgen).
     * clang-format: the ebuild's `bin-finder.py` (ebuild:667) deletes `buildtools/linux64-format/clang-format`, which is also a bundled binary. Point :115 at `$(get_llvm_prefix)/bin/clang-format` or drop it; it's optional, only formatting.
  3. **Crubit sources:**
     * `build_overrides/crubit.gni:5` `crubit_src_dir` → e.g. `//third_party/crubit/src`, with the ebuild symlinking `third_party/crubit/src -> /usr/lib/crubit/<slot>/lib/third_party/crubit`.
     * `build/rust/crubit/BUILD.gn:25` include_dirs `//third_party/rust-toolchain/lib` → the dir that contains `third_party/crubit/…`.
     * Lazy alternative: create `third_party/rust-toolchain/{bin/cc_bindings_from_rs,bin/rustfmt,lib/third_party/crubit}` symlinks and patch only 1, 2 (asserts) and 4.
  4. **Std bindings for prebuilt std** (new; the only non-trivial part):
     * In the prebuilt branch of `build/rust/std/BUILD.gn` (the `else` at :243-375), when `enable_cpp_api_from_rust`, define `core_bindings`/`alloc_bindings`/`std_bindings` with a small template.
     * The action runs a wrapper `.py` that globs `$(rustc --print target-libdir)/lib<crate>-*.rmeta`. It sets `RUSTC_BOOTSTRAP=1` and runs `cc_bindings_from_rs --enable-rmeta-interface --source-crate-name=<crate> --extern <crate>=<rmeta> [--extern deps…] --target <triple> --h-out $root_gen_dir/third_party/crubit/support/rs_std/rs_<crate>.h --rs-out ….impl.rs --crubit-support-path-format '"third_party/crubit/support/{header}"' --crate-namespace=self=rs::<crate> --crate-feature=self=always_specialize_generics_in_cpp_api_from_rust [--crate-header/--crate-namespace for core/alloc]`. These are the exact args tested in scratch `t1`.
     * Add a `rust_library` for the `.impl.rs` (deps: `//build/rust/crubit:cpp_api_from_rust_bindings_rs_deps`).
     * Add a `source_set` exporting the header, with the same `metadata` keys (`crate_header`/`crate_namespace`/`crate_feature`) as cpp_api_from_rust.gni:281-285.
     * Add `group("std_bindings")`.
     * Point `build/rust/crubit/BUILD.gn:13-15` and cpp_api_from_rust.gni:98 at these when `rust_prebuilt_stdlib`.
  5. **Ebuild:**
     * `!bundled-toolchain? ( dev-util/crubit )` in BDEPEND.
     * In `pkg_setup` after `rust_pkg_setup`: `has_version -b "dev-util/crubit:${RUST_SLOT}"` or die ("install dev-util/crubit:${RUST_SLOT} or set ERUST_SLOT_OVERRIDE"), and run `/usr/lib/crubit/${RUST_SLOT}/bin/cc_bindings_from_rs --help` to catch a stale driver hash.
     * Don't use `rust_check_deps()`: rust.eclass declares `RUST_SLOT` `local` inside `_get_rust_slot` (rust.eclass:434-437), so the chosen slot is lost when the hook is used.
     * gn arg `rust_crubit_root="${EPREFIX}/usr/lib/crubit/${RUST_SLOT}"`.
     * `RUSTC_BOOTSTRAP=1` is already exported (ebuild:387). It's needed for the `-Zallow-features` list in build/rust/crubit/BUILD.gn.
  6. Drop the cbor/PVT/IFT stubs, the font/web_package reverts and the qr workaround. Everything follows upstream.
* **Cross-machine:** crubit and rust[dist] are build-only (BDEPEND). Generated code is compiled into chrome. The runtime machine needs nothing.

### B4. `dev-util/crubit` draft ebuild

`dev-util/crubit/crubit-1.98.1_p20260908.ebuild` (+ metadata.xml, Manifest with 83 DIST entries computed from the exact crates.io/GitHub files).

* **Versioning:**
  * PV = `<rust version>_p<crubit commit date>`.
  * `SLOT=$(ver_cut 1-3)` = Rust slot: one crubit per Rust slot, and slots can coexist.
  * `RUST_MIN_VER=RUST_MAX_VER=` slot, `RUST_REQ_USE="dist(-)"` (forces source rust with USE=dist; the rust-bin alternative is unsatisfiable). Explicit `BDEPEND+=dev-lang/rust:${SLOT}[dist]`, `RDEPEND=dev-lang/rust:${SLOT}`.
  * `portageq metadata` resolves SLOT/BDEPEND/LICENSE/SRC_URI correctly [V].
* **src_prepare:**
  * Builds a private sysroot in `${WORKDIR}`: symlinks to the installed std, plus rustc-dev rmeta extracted from `/usr/lib/rust/${SLOT}/dist/rustc-dev-${SLOT}-<triple>.tar.xz`.
  * Verifies that the tarball's `librustc_driver-<hash>.so` exists in the installed slot, then symlinks it. The installed copy is stripped, so `cmp` is not usable; the hash is in the file name.
* **src_compile:** `RUSTC_BOOTSTRAP=1`, `RUSTFLAGS+=--sysroot=… -Wl,-rpath,/usr/lib/rust/${SLOT}/lib`, `cargo_src_compile --locked -p cc_bindings_from_rs --bin cc_bindings_from_rs`, then a `--help` smoke test.
* **src_install:** `/usr/lib/crubit/${SLOT}/bin/cc_bindings_from_rs` + `/usr/lib/crubit/${SLOT}/lib/third_party/crubit/{BUILD.gn,LICENSE,crubit.gni,support}`. This is the same layout as Chromium's toolchain.
* **Assumed, not tested:**
  * The ebuild itself in portage.
  * Gentoo's dist tarball name/layout. It's the same `x.py dist` code, so it should match the official layout (`rustc-dev-<ver>-<triple>/rustc-dev/lib/rustlib/<triple>/lib/*`).
  * Cargo target rustflags also apply to build scripts/proc-macros when not cross-compiling.
  * Gentoo's librustc_driver finds `libLLVM.so.22.1` via ld.so.conf. Its RUNPATH is `$ORIGIN/../lib` only [V], and the official tarball needed `-L` for its bundled libLLVM. Gentoo links system LLVM, so this should be fine.

## Recommendation, effort, risk

**Recommended:** the Crubit route.
1. Set `dev-lang/rust:1.98.1` USE=dist and rebuild.
2. Install `dev-util/crubit:1.98.1`.
3. Apply the Chromium GN patch above with `enable_cpp_api_from_rust=true`.

| Item | Effort | Risk |
|---|---|---|
| USE=dist rebuild of rust | none to write; one rust rebuild (+dist time, several hundred MB on build host) | low (existing flag) |
| dev-util/crubit | done (draft); per Chromium CRUBIT_REVISION bump: new PV + CRATES refresh (pycargoebuild); per Rust slot: copy ebuild | low-medium: future crubit revs may need stable-rustc backports (copium cbit152 precedent) |
| Chromium patch: condition/paths/clang-format | ~30 lines | low |
| Chromium patch: prebuilt-std bindings via rmeta mode | ~150 lines GN+py, new | medium: not gn-tested; Crubit side verified |
| Runtime ABI drift (rust rebuilt with other flags) | n/a | caught at build start (`--help` smoke test; hashed driver) |

**No-Crubit alternative:**
* Steps:
  * cxx revert for font_format (small).
  * Revert ≈8 upstream commits for web_package/signed bundles (≈3k lines, growing).
  * Stubs for PVT and IFT, the CBOR buildflag.
  * qr follows automatically.
* This keeps default-active code on code that upstream deleted (C++ parsing of untrusted bundles), and the upstream TODOs (crbug 535682335, 533546009) plan to delete the remaining C++ fallbacks. Not recommended.
