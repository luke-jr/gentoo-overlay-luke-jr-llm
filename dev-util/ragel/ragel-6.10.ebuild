# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="Compiles finite state machines from regular languages into executable code"
HOMEPAGE="http://www.colm.net/open-source/ragel/"
SRC_URI="http://www.colm.net/files/ragel/${P}.tar.gz"

LICENSE="GPL-2"
# Ragel 6 in a slot of its own, installed as ragel-6, for systems that keep ::gentoo's
# dev-util/ragel:0 at Ragel 7 (::gentoo has Ragel 6 and 7 both in slot 0): HarfBuzz needs exactly
# 6.10 to regenerate its state machines. Keep the version equal to ::gentoo's 6.10 (no revision):
# for || ( =dev-util/ragel-6*:0 dev-util/ragel:6 ), Portage moves a choice with a higher version
# of the same package to the front, so a higher one here would win over an installed
# ::gentoo 6.10.
SLOT="6"
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
