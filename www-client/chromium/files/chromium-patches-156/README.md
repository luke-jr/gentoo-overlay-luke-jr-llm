# chromium-patches
Patches needed to build Chromium in the Gentoo ebuild context.

Patches should be applied as follows:

- common/: always required - should be applied for both bundled and unbundled toolchain builds
- ppc64le/: required on ppc64le
- {llvm,rust}/: unbundled toolchain only - unconditionally applied
- {llvm,rust}/lt-ver: as above, apply if llvm/rust less than this ver
- toolchain/: applied if using the unbundled (system) toolchain
