# Copyright 2026 Maidware Project
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="Maid Runner - fast app/command launcher"
HOMEPAGE="https://codeberg.org/Maidware_Project/Maid-Runner"
SRC_URI="https://codeberg.org/Maidware_Project/Maid-Runner/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="dev-lang/python"

S="${WORKDIR}/maid-runner"

src_install() {
	DESTDIR="${D}" bash install.sh --prefix=/usr --no-packages --no-config || die
}
