# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# The rustc-dev component of dev-lang/rust: the compiler's own crates
# (rustc_driver, rustc_interface, ...), which rustc drivers such as
# dev-util/crubit link against. It is what `rustup component add rustc-dev`
# installs into a toolchain. dev-lang/rust with USE=dist builds it, but only
# leaves it as a tarball in /usr/lib/rust/<slot>/dist/; this installs it into
# that slot's sysroot, so rustc finds the crates without extra flags.
#
# The crates belong to one specific build of dev-lang/rust (the driver's
# file name carries its hash): rebuilding dev-lang/rust:<slot> requires
# rebuilding this, which src_install and pkg_postinst point out.
#
# Not installed: lib/rustlib/rustc-src (the compiler's source code, only used
# by IDE tooling such as rust-analyzer).

inherit rust-toolchain

DESCRIPTION="The Rust compiler's own crates (rustc-dev component) for dev-lang/rust"
HOMEPAGE="https://www.rust-lang.org/"
S="${WORKDIR}"

LICENSE="|| ( MIT Apache-2.0 ) BSD BSD-1 BSD-2 BSD-4"
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"

DEPEND="dev-lang/rust:${SLOT}[dist]"
RDEPEND="${DEPEND}"

src_unpack() {
	local triple=$(rust_abi)
	local tarball="${ESYSROOT}/usr/lib/rust/${SLOT}/dist/rustc-dev-${SLOT}-${triple}.tar.xz"
	[[ -f ${tarball} ]] ||
		die "${tarball} not found; re-emerge dev-lang/rust:${SLOT} with USE=dist"

	einfo "Unpacking ${tarball} ..."
	tar -xJf "${tarball}" -C "${WORKDIR}" --wildcards \
		"rustc-dev-${SLOT}-${triple}/rustc-dev/lib/rustlib/${triple}/lib/*" ||
		die "Failed to unpack rustc-dev"
}

src_install() {
	local triple=$(rust_abi)
	local rustroot="/usr/lib/rust/${SLOT}"
	local libdir="${rustroot}/lib/rustlib/${triple}/lib"
	local src="${WORKDIR}/rustc-dev-${SLOT}-${triple}/rustc-dev/lib/rustlib/${triple}/lib"

	# The crates only work with the librustc_driver they were built with, and
	# its hash is in the file name. Use the installed (stripped) copy of exactly
	# that file instead of a second copy, and refuse a mismatching tarball.
	local drv=( "${src}"/librustc_driver-*.so )
	if [[ ${#drv[@]} -ne 1 || ! -f ${drv[0]} ]]; then
		eerror "librustc_driver-*.so in rustc-dev's lib/rustlib/${triple}/lib:"
		eerror "  $(cd "${src}" && echo librustc_driver-*.so)"
		eerror "shared objects there: $(cd "${src}" && echo *.so)"
		die "rustc-dev contains no single librustc_driver"
	fi
	local drv_name=${drv[0]##*/}
	[[ -f ${ESYSROOT}${rustroot}/lib/${drv_name} ]] ||
		die "rustc-dev does not match the installed rustc (${rustroot}/lib/${drv_name} missing); re-emerge dev-lang/rust:${SLOT}"

	insinto "${libdir}"
	local f
	for f in "${src}"/*; do
		[[ ${f} == "${drv[0]}" ]] && continue
		# The tarball has an empty lib/self-contained/ (nothing to install).
		if [[ -d ${f} ]]; then
			[[ -z $(ls -A "${f}") ]] && continue
			die "Unexpected directory in rustc-dev: ${f##*/}"
		fi
		# dev-lang/rust owns the rust-std files in the same directory.
		[[ -e ${ESYSROOT}${libdir}/${f##*/} ]] && die "${f##*/} would overwrite a file of dev-lang/rust"
		doins "${f}"
	done
	dosym -r "${rustroot}/lib/${drv_name}" "${libdir}/${drv_name}"
}

pkg_postinst() {
	elog "These crates are tied to the dev-lang/rust:${SLOT} build installed now."
	elog "After rebuilding dev-lang/rust:${SLOT}, rebuild ${CATEGORY}/${PN}:${SLOT}"
	elog "(and anything built against it, e.g. dev-util/crubit:${SLOT})."
}
