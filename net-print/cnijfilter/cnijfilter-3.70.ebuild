# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit eutils autotools flag-o-matic multilib

DESCRIPTION="Canon InkJet Printer Driver for Linux (Pixus/Pixma-Series)."
HOMEPAGE="http://support-sg.canon-asia.com/contents/SG/EN/0100469302.html"
SRC_URI="http://gdlp01.c-wss.com/gds/3/0100004693/01/${PN}-source-${PV}-1.tar.gz"

LICENSE="GPL-2 cnijfilter"
SLOT="0"
KEYWORDS="~amd64 ~x86"
PRINTER_USE=( ip100 mx710 mx890 mx370 mx430 mx510 e600 )
PRINTER_ID=( 303 394 395 396 397 398 399 )
IUSE="${PRINTER_USE[@]} +net +servicetools"

RDEPEND="
	>=media-libs/libpng-1.5
	>=media-libs/tiff-3.4
	>=net-print/cups-1.4
	servicetools? (
		>=dev-libs/libxml2-2.7.3-r2
		>=x11-libs/gtk+-2.6:2
	)
"
DEPEND="${DEPEND}
	sys-devel/gettext
"

REQUIRED_USE="|| ( ${PRINTER_USE[@]} )"

S="${WORKDIR}/${PN}-source-${PV}-1"

_dir_build() {
	local dirs=$1
	local command=$2
	local d

	[[ $# -ne 2 ]] && die "Call as: _dir_build DIRS COMMAND"

	for d in ${dirs}; do
		local suffix=""
		echo ">>> Working in: ${d}"
		pushd ${d} >/dev/null
		# progpath must be set otherwise we go for /usr/local/bin
		${command} --enable-progpath="${EPREFIX}/usr/bin"
		popd > /dev/null
	done
}

_printer_dir_build() {
	local command=$1
	local d

	[[ $# -ne 1 ]] && die "Call as: _printer_dir_build COMMAND"

	for (( i=0; i<${#PRINTER_USE[@]}; i++ )); do
		local name="${PRINTER_USE[$i]}"
		if use ${name}; then
			for d in ${DIRS_PRINTER}; do
				echo ">>> Working in: ${name}/${d}"
				pushd ${name}/${d} > /dev/null
				# substitution here is for configure phase
				${command/\%name\%/${name}}
				popd > /dev/null
			done
		fi
	done
}

pkg_setup() {
	[[ -z ${LINGUAS} ]] && LINGUAS="en"

	DIRS="libs pstocanonij backend"
	use net && DIRS+=" backendnet"
	use servicetools && DIRS+=" cngpij cngpijmon cngpijmon/cnijnpr"
	DIRS_PRINTER="cnijfilter"
	use servicetools && DIRS_PRINTER+=" printui lgmon"
}

src_prepare() {
	local d i

	# missing macros directory make aclocal fail
	mkdir printui/m4 || die

	epatch \
		"${FILESDIR}/${PN}"-3.70-png.patch \
		"${FILESDIR}/${PN}"-3.70-ppd.patch \
		"${FILESDIR}/${PN}"-3.70-ppd2.patch \
		"${FILESDIR}/${PN}"-3.70-libexec-cups.patch \
		"${FILESDIR}/${PN}"-3.70-libexec-backend.patch

	_dir_build "${DIRS}" "eautoreconf"
	_dir_build "${DIRS_PRINTER}" "eautoreconf"

	for (( i=0; i<${#PRINTER_USE[@]}; i++ )); do
		local name="${PRINTER_USE[$i]}"
		local pid="${PRINTER_ID[$i]}"
		if use ${name}; then
			mkdir -p ${name} || die
			ln -s "${S}"/${pid} ${name}/ || die
			ln -s "${S}"/com ${name}/ || die
			for d in ${DIRS_PRINTER}; do
				cp -a ${d} ${name} || die
			done
		fi
	done
}

src_configure() {
	local d i

	_dir_build "${DIRS}" "econf"
	_dir_build "lgmon" "econf" # workaround for cnijnpr which needs generic compiled lgmon
	_printer_dir_build "econf --program-suffix=%name%"
}

src_compile() {
	_dir_build "lgmon" "emake" # workaround for cnijnpr which needs generic	compiled lgmon
	_dir_build "${DIRS}" "emake"
	_printer_dir_build "emake"
}

src_install() {
	local _libdir="${EPREFIX}/usr/$(get_libdir)"
	local _libdir_pkg=libs_bin$(use amd64 && echo 64 || echo 32)
	local _ppddir="${EPREFIX}/usr/share/cups/model"

	_dir_build "${DIRS}" "emake DESTDIR=${D} install"
	_printer_dir_build "emake DESTDIR=${D} install"

	if use net; then
		pushd com/${_libdir_pkg} > /dev/null
		dodir ${_libdir}
		# no doexe to preserve symlinks
		cp -a libcnnet.so* "${D}/${_libdir}" || die
		popd > /dev/null
	fi

	for (( i=0; i<${#PRINTER_USE[@]}; i++ )); do
		local name="${PRINTER_USE[$i]}"
		local pid="${PRINTER_ID[$i]}"
		if use ${name}; then
			dodir ${_libdir}
			# no doexe due to symlinks
			cp -a "${pid}/${_libdir_pkg}"/* "${D}/${_libdir}" || die
			exeinto ${_libdir}/cnijlib
			doexe ${pid}/database/*
			insinto ${_ppddir}
			doins ppd/canon${name}.ppd
		fi
	done
}

pkg_postinst() {
	einfo ""
	einfo "For installing a printer:"
	einfo " * Restart CUPS: /etc/init.d/cupsd restart"
	einfo " * Go to http://127.0.0.1:631/"
	einfo "   -> Printers -> Add Printer"
	einfo ""
	einfo "If you experience any problems, please visit:"
	einfo " http://forums.gentoo.org/viewtopic-p-3217721.html"
	einfo ""
}
