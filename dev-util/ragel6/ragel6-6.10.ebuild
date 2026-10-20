# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="Compiles finite state machines from regular languages into executable code"
HOMEPAGE="http://www.colm.net/open-source/ragel/"
SRC_URI="http://www.colm.net/files/ragel/ragel-${PV}.tar.gz"
S="${WORKDIR}/ragel-${PV}"

LICENSE="GPL-2"
# Ragel 6, installed as ragel-6, for systems that keep ::gentoo's dev-util/ragel at Ragel 7
# (::gentoo has Ragel 6 and 7 in the same slot): HarfBuzz needs exactly 6.10 to regenerate its
# state machines. A package of its own, not a dev-util/ragel slot, so that Portage keeps choosing
# ::gentoo's dev-util/ragel-6.10 for the chromium ebuild's || dependency when that is installed.
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# We need to get the txl language in Portage to have the tests :(
RESTRICT="test"

src_prepare() {
	default
	eautoreconf
}

src_install() {
	newbin ragel/ragel ragel-6
	newman doc/ragel.1 ragel-6.1
}
