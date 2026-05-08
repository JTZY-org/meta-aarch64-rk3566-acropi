SUMMARY = "Rockchip packing tools for RK3566 (afptool, rkImageMaker)"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://../Licenses/gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

# These are pre-compiled x86_64 binaries from AmberELEC uboot_rg353 repository
SRC_URI = "git://github.com/AmberELEC/uboot_rg353.git;protocol=https;branch=main"
SRCREV = "afab29d9258edd48b171ff398898d05469000fe3"

S = "${WORKDIR}/git/rk3566_tool"

do_compile() {
    :
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/afptool ${D}${bindir}/
    install -m 0755 ${S}/rkImageMaker ${D}${bindir}/
    # Provide a symlink for compatibility, but note that rkImageMaker 
    # has different arguments than the older img_maker.
    ln -sf rkImageMaker ${D}${bindir}/img_maker
}

inherit native
