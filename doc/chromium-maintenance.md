# Chromium: maintenance

How a new Chromium version gets into this overlay, and how it is checked. This is the procedure 157
was added with (and 156 updated from .12 to .47).

## Which version, which slot

- **Channel and `SLOT`:** look the version up for Linux, e.g.
  `https://chromiumdash.appspot.com/fetch_releases?channel=Beta&platform=Linux`. As in `::gentoo`, the
  `SLOT` is the channel: `stable`, `beta` or `unstable` (dev). It is not just a label: it decides the
  install directory (`chromium-browser-<slot>`), the profile directory and the channel the browser
  reports. Google's "Early Stable" releases are for Windows and Mac only; such a build is Beta on
  Linux. When a version moves to another channel, it gets a new ebuild (a revision bump if the
  version is the same), so installed copies move too.
- **Source:** Google's official "lite" tarball,
  `https://commondatastorage.googleapis.com/chromium-browser-official/chromium-<version>-lite.tar.xz`;
  check it against the `.hashes` file next to it. For a version without a tarball yet, or for fixes
  made on the release branch after a tag, `scripts/chromium-delta/README.md` describes the upgrade
  patches (the security fixes on the branch are included).

## A new major version

1. **Start from the previous ebuild:** copy it, and set `SLOT` (above).
2. **Patches:** copy `files/chromium-patches-<previous>/` to `files/chromium-patches-<major>/`, and
   check every patch (the Gentoo patchset, copium's selection, and the overlay's own
   `files/chromium-*.patch`) against the new tree:
   - one that no longer applies is rebased (as `chromium-<major>-<name>.patch` when it differs);
   - one that reverse-applies is upstream now, and is dropped;
   - one whose purpose upstream now serves another way is dropped too (157: the terms dialog patch).
   Note why in the commit.
3. **Pins:** read them from the new tree, as upstream's `DEPS` and scripts give them:
   - `GN_MIN_VER` and `dev-build/gn` at the revision `DEPS` uses;
   - `CRUBIT_DATE`: the commit date of `CRUBIT_REVISION` in `tools/rust/update_rust.py`, with a new
     `dev-util/crubit-<Rust version>_p<date>` (one slot per version);
   - Khronos registries, Vulkan-Headers and Vulkan-Docs at `DEPS`' revisions;
   - `cddlconv`: the version chromium-bidi's checked-in protocol types name;
   - Unicode versions of the tables that are regenerated (HarfBuzz, ICU, RE2, …);
   - `ESBUILD_VER`, `TSGO_VER`, `DEVTOOLS_TS_VER`, `ROLLUP_VER`, `NODE_VER`.
4. **Per-major packages:** `dev-util/gnrt:<major>` (from the new tarball's `tools/crates/gnrt`),
   `dev-util/chromium-rust-crates:<major>` (the vendored crates' generators at the commits the crates
   were published from, per `.cargo_vcs_info.json`) and `dev-util/chromium-node-modules:<major>` (the
   npm packages whose generated files are replaced, at the versions in the tree, from their git
   sources: npm's `gitHead`, or the release tag).
5. **Bundled sources:** a new `third_party` directory the build uses must be added to `keeplibs`,
   or the unbundling deletes it (157: `third_party/sframe`). When the build stops on a missing input,
   `ninja -C out/Release -t inputs chrome chromedriver chrome_sandbox` lists every input of the
   targets, so all missing ones can be found at once.
6. **Generated files:** new generated files in the tarball are classified with
   `scripts/chromium-delta/tarball-generated.py`; new checked-in generated sources need a
   regeneration step and a pattern in `chromium_regenerated_outputs`, or an entry in
   `doc/chromium-generated-files.md`'s exceptions.
7. **npm keep list:** `files/chromium-<major>-node-modules.txt` starts as the previous version's.
   After the first successful build, regenerate it with `scripts/chromium-node-modules-used.py` (in
   `out/Release`, with the tarball's npm packages restored in the tree; see its usage).

## A new release of the same major

This is how 156 went from .47 to .78_pre (on the .73 tarball).

1. **Rename the ebuild** (keep the `SLOT`, unless the release changed channel), and replace the
   tarball's line in the `Manifest` (check the tarball against its `.hashes` first).
2. **Fixes after the release:** Google tags every candidate build on the release branch
   (`refs/tags/<version>`, in the branch's log), but publishes a tarball only for releases. When
   the branch has a newer tag than the newest tarball, build that tag as a `_pre` ebuild
   (`chromium-<tag>_pre`, `CHROMIUM_TARBALL_PV` = the tarball's version): an upgrade patch
   `files/chromium-<tarball>-to-<tag>.patch` made with `scripts/chromium-delta` (its README),
   which also sets `chrome/VERSION` and the version stamps to the tag's. `_pre` sorts below the
   real release, so a later tarball of that version replaces it. Check that every patched file is
   byte-identical to its version at the tag; a blobless git fetch is more reliable for that than
   Gitiles, which often times out.
3. **Other fixes** carried for this major (e.g. `chromium-156-cve-2026-110914.patch`): look for
   them in the new tag's log; drop the ones it has, and update the date in the others' headers.
4. **Per-major packages:** compare the two tarballs' files (hash each file of both). If the vendored
   Rust crates (`third_party/rust`), the npm packages (`third_party/node`, DevTools'
   `node_modules` and `front_end/third_party`) and `tools/crates` are unchanged, `gnrt`,
   `chromium-rust-crates` and `chromium-node-modules` stay as they are.
5. Build and check as below.

## Building and checking

- Build offline (nothing may be downloaded during the build), with the flags you use, and with
  `NINJAOPTS="-k 0"` so one failure doesn't hide the next.
- `scripts/chromium-tests/` has the checks: that every checked-in generated file the ebuild moved
  aside was made again, and runtime checks of the installed browser (components, DevTools, WebDriver
  BiDi, WebGL, the "Restore pages?" fix). Compare their results with the previous version's.
- Update `doc/chromium.md` (the per-version differences) and the package table in `README.md`.
