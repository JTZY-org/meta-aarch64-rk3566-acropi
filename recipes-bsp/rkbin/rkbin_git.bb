SUMMARY = "Rockchip Firmware and Tools"
DESCRIPTION = "Rockchip firmware binaries and tools for bootloader generation"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://LICENSE;md5=11e3673115959bf596feaaa6ea7ce9a5"

SRC_URI = "git://github.com/rockchip-linux/rkbin.git;protocol=https;branch=master"
SRCREV = "b4558da0860ca48bf1a571dd33ccba580b9abe23"

# We don't need to compile anything, just install prebuilt tools
do_compile[noexec] = "1"

do_install() {
    # Install tools to bindir for native usage
    install -d ${D}${bindir}
    install -m 0755 ${S}/tools/loaderimage ${D}${bindir}/
    install -m 0755 ${S}/tools/mkkrnlimg ${D}${bindir}/
    install -m 0755 ${S}/tools/resource_tool ${D}${bindir}/
    install -m 0755 ${S}/tools/upgrade_tool ${D}${bindir}/
    install -m 0755 ${S}/tools/boot_merger ${D}${bindir}/

    # Install binaries and configs for deployment (available to other recipes)
    install -d ${D}${datadir}/rkbin/bin/rk35
    install -d ${D}${datadir}/rkbin/RKBOOT
    
    # Copy all rkbin content to preserve paths for .ini files
    cp -r ${S}/bin ${D}${datadir}/rkbin/
    cp -r ${S}/RKBOOT ${D}${datadir}/rkbin/

    # Symbolic links for easy access
    ln -sf bin/rk35/rk3566_ddr_1056MHz_v1.18.bin ${D}${datadir}/rkbin/rk3566_ddr.bin
    ln -sf bin/rk35/rk3568_bl31_v1.43.elf ${D}${datadir}/rkbin/rk3568_bl31.elf
}

FILES:${PN} += "${datadir}/rkbin"
FILES:${PN}-native += "${datadir}/rkbin"

BBCLASSEXTEND = "native"