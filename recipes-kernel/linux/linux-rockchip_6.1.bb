LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

inherit kernel

SRC_URI = "git://github.com/rockchip-linux/kernel.git;protocol=https;branch=develop-6.1 \
           file://cpufreq.cfg"

SRCREV = "d2b4477a1df699e6639e83837c7dc45ea1d1d73f"

KBUILD_DEFCONFIG = "rockchip_linux_defconfig"

DEPENDS += "e2fsprogs-native u-boot-tools-native"
INSANE_SKIP:${PN} += "buildpaths"
INSANE_SKIP:${PN}-src += "buildpaths"

do_deploy:append() {
    mkdir -p ${WORKDIR}/boot-image/boot
    
    # 1. Copy Kernel and DTB
    cp ${B}/arch/${ARCH}/boot/Image ${WORKDIR}/boot-image/boot/
    if ls ${B}/arch/${ARCH}/boot/dts/rockchip/rk3566*.dtb >/dev/null 2>&1; then
        cp ${B}/arch/${ARCH}/boot/dts/rockchip/rk3566*.dtb ${WORKDIR}/boot-image/boot/
    fi

    # 4. Generate boot.img
    if [ -f "${DEPLOYDIR}/boot.img" ]; then
        rm "${DEPLOYDIR}/boot.img"
    fi
    dd if=/dev/zero of=${DEPLOYDIR}/boot.img bs=1M count=64
    mkfs.ext2 -F -d ${WORKDIR}/boot-image/boot ${DEPLOYDIR}/boot.img

    # 5. Clean up standard kernel artifacts
    find ${DEPLOYDIR} -type f ! -name "boot.img" -delete
    find ${DEPLOYDIR} -type l -delete 
}

S = "${UNPACKDIR}/linux-rockchip-6.1"

do_configure:append() {
    if [ -f "${UNPACKDIR}/cpufreq.cfg" ]; then
        cat "${UNPACKDIR}/cpufreq.cfg" >> "${B}/.config"
    fi
    echo "&uart2 { status = \"okay\"; };" >> ${S}/arch/arm64/boot/dts/rockchip/rk3566-evb2-lp4x-v10.dts
}
