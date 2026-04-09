LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=bbea815ee2795b2f4230826c0c6b8814"

inherit kernel

LINUX_VERSION = "4.19"
LINUX_VERSION_EXTENSION = "-acropi-final-v3"

# Note: We provide a local 'defconfig' file in SRC_URI which serves as the base.
# KBUILD_DEFCONFIG is removed to ensure the local file is prioritized.

SRC_URI = "git://github.com/rockchip-linux/kernel.git;protocol=https;branch=develop-4.19 \
           file://defconfig \
           file://acropi.cfg \
           file://rk3566-acropi-lp4x.dts \
           file://extlinux.conf \
           "

SRCREV = "f39b590ea11da2d897644e42119ba5099b2eefc8"

DEPENDS += "e2fsprogs-native u-boot-tools-native"
INSANE_SKIP:${PN} += "buildpaths"
INSANE_SKIP:${PN}-src += "buildpaths"

do_configure:append() {
    # 1. Integrate the custom DTS into the kernel source tree
    cp ${UNPACKDIR}/rk3566-acropi-lp4x.dts ${S}/arch/arm64/boot/dts/rockchip/
    
    # 2. Register the new DTS in the Makefile if not already present
    if ! grep -q "rk3566-acropi-lp4x.dtb" ${S}/arch/arm64/boot/dts/rockchip/Makefile; then
        sed -i '/dtb-$(CONFIG_ARCH_ROCKCHIP) +=/a \\trk3566-acropi-lp4x.dtb \\' ${S}/arch/arm64/boot/dts/rockchip/Makefile
    fi

    # 3. Sync configuration and resolve dependencies
    # Note: Manually merge fragments as 'kernel' class doesn't do it automatically like 'kernel-yocto'
    if [ -f "${UNPACKDIR}/acropi.cfg" ]; then
        cat ${UNPACKDIR}/acropi.cfg >> ${B}/.config
    fi
    oe_runmake -C ${S} O=${B} olddefconfig
}

do_deploy:append() {
    mkdir -p ${WORKDIR}/boot-image/boot
    # Clear old files to prevent stale images
    rm -rf ${WORKDIR}/boot-image/boot/*
    
    cp ${B}/arch/${ARCH}/boot/Image ${WORKDIR}/boot-image/boot/
    # Explicitly copy the correct DTB
    cp ${B}/arch/${ARCH}/boot/dts/rockchip/rk3566-acropi-lp4x.dtb ${WORKDIR}/boot-image/boot/
    
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
