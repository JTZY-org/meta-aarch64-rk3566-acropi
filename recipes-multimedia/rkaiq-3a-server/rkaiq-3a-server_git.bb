SUMMARY = "Rockchip RKAIQ (Auto Image Quality) server and library"
DESCRIPTION = "RKAIQ is the Rockchip Auto Image Quality stack for ISP and 3A algorithms."
HOMEPAGE = "https://github.com/TSKangetsu/rkaiq_3A_server-rk356x"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://NOTICE;md5=9645f39e9db895a4aa6e02cb57294595"

SRC_URI = "git://github.com/TSKangetsu/rkaiq_3A_server-rk356x.git;protocol=https;branch=main"
SRCREV = "78febea4907b1a11a167f02f682c02ba63d149db"

S = "${WORKDIR}/git"

inherit cmake

DEPENDS = "libdrm coreutils-native vim-native m4-native"

do_install:append() {
    # Remove init scripts to prevent auto-start as requested by user
    rm -rf ${D}${sysconfdir}
}

# The project hardcodes SOC as rk356x and ISP_HW_V21 in root CMakeLists.txt

# The library is unversioned
FILES:${PN} = " \
    ${bindir}/rkaiq_3A_server \
    ${bindir}/rkaiq_tool_server \
    ${bindir}/rkisp_demo \
    ${bindir}/rkisp_parser_demo \
    ${libdir}/librkaiq.so \
"

FILES:${PN}-dev = "${includedir}"

INSANE_SKIP:${PN} += "dev-so"

RPROVIDES:${PN} += "rkaiq"
