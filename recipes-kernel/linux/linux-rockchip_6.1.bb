LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

inherit kernel

SRC_URI = "git://github.com/rockchip-linux/kernel.git;protocol=https;branch=develop-6.1 \
           file://cpufreq.cfg \
           file://lttng.cfg \
           file://extlinux.conf \
           file://monitor.cfg \
           file://0001-Add-Acropi-RK3566-DTS-and-update-Makefile.patch;patchdir=.. \
           "

SRCREV = "${AUTOREV}"

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
    if [ -f "${UNPACKDIR}/cpufreq.cfg" ]; then
        cat "${UNPACKDIR}/cpufreq.cfg" >> "${B}/.config"
    fi
    if [ -f "${UNPACKDIR}/lttng.cfg" ]; then
        cat "${UNPACKDIR}/lttng.cfg" >> "${B}/.config"
    fi
    if [ -f "${UNPACKDIR}/monitor.cfg" ]; then
        cat "${UNPACKDIR}/monitor.cfg" >> "${B}/.config"
    fi
}
