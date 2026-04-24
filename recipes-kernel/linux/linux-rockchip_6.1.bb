LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

inherit kernel

SRC_URI = "git://github.com/rockchip-linux/kernel.git;protocol=https;branch=develop-6.1 \
           file://rk3566-acropi.cfg \
           file://extlinux.conf \
           file://rk3566-acropi-lp4x.dts \
           "

SRCREV = "d2b4477a1df699e6639e83837c7dc45ea1d1d73f"

KBUILD_DEFCONFIG = "rockchip_linux_defconfig"

DEPENDS += "e2fsprogs-native u-boot-tools-native"
INSANE_SKIP:${PN} += "buildpaths"
INSANE_SKIP:${PN}-src += "buildpaths"

do_deploy:append() {
    mkdir -p ${WORKDIR}/boot-image/boot
    cp ${B}/arch/${ARCH}/boot/Image ${WORKDIR}/boot-image/boot/
    if ls ${B}/arch/${ARCH}/boot/dts/rockchip/rk3566*.dtb >/dev/null 2>&1; then
        cp ${B}/arch/${ARCH}/boot/dts/rockchip/rk3566*.dtb ${WORKDIR}/boot-image/boot/
    fi
    if [ -f "${UNPACKDIR}/extlinux.conf" ]; then
        mkdir -p ${WORKDIR}/boot-image/boot/extlinux
        cp "${UNPACKDIR}/extlinux.conf" ${WORKDIR}/boot-image/boot/extlinux/
    fi
    if [ -f "${DEPLOYDIR}/boot.img" ]; then
        rm "${DEPLOYDIR}/boot.img"
    fi
    dd if=/dev/zero of=${DEPLOYDIR}/boot.img bs=1M count=64
    mkfs.ext2 -F -d ${WORKDIR}/boot-image/boot ${DEPLOYDIR}/boot.img
    find ${DEPLOYDIR} -type f ! -name "boot.img" -delete
    find ${DEPLOYDIR} -type l -delete 
}

S = "${UNPACKDIR}/git"

do_configure:append() {
    cp ${UNPACKDIR}/rk3566-acropi-lp4x.dts ${S}/arch/arm64/boot/dts/rockchip/
    if ! grep -q "rk3566-acropi-lp4x.dtb" ${S}/arch/arm64/boot/dts/rockchip/Makefile; then
        sed -i "/rk3566-evb2-lp4x-v10.dtb/a dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3566-acropi-lp4x.dtb" ${S}/arch/arm64/boot/dts/rockchip/Makefile
    fi
    if [ -f "${UNPACKDIR}/rk3566-acropi.cfg" ]; then
        cat "${UNPACKDIR}/rk3566-acropi.cfg" >> "${B}/.config"
    fi
    sed -i '/MPP_GIT_REVISION :=/,/info")/c\MPP_GIT_REVISION := v1.0.0-acropi' ${S}/drivers/video/rockchip/mpp/Makefile
}
