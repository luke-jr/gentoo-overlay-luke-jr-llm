# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="Compiles finite state machines from regular languages into executable code"
HOMEPAGE="http://www.colm.net/open-source/ragel/"
SRC_URI="http://www.colm.net/files/ragel/${P}.tar.gz"

LICENSE="GPL-2"
# Ragel 6, installed as ragel-6 next to ::gentoo's dev-util/ragel:0 (which may be Ragel 7):
# HarfBuzz needs exactly 6.10 to regenerate its state machines.
SLOT="6"
KEYWORDS="~amd64 ~arm64 ~ppc64 ~x86"

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
