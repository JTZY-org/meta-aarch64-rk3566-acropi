FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI = "git://github.com/rockchip-linux/u-boot.git;protocol=https;branch=next-dev"

SRCREV = "${AUTOREV}"

UBOOT_MACHINE = "rk3568_defconfig"

COMPATIBLE_MACHINE = "rk3566-acropi"

LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

EXTRA_OEMAKE:append = " KCFLAGS='-Wno-error=maybe-uninitialized -Wno-error=enum-int-mismatch -Wno-error=unused-variable'"

DEPENDS += "rkbin-native u-boot-tools-native"

# 纯粹的 BootFlow 2：将 ATF 直接注入 U-Boot FIT 镜像
export BL31 = "${STAGING_DATADIR_NATIVE}/rkbin/bin/rk35/rk3568_bl31_v1.43.elf"

do_compile:append() {
    # 1. 生成官方 idbloader.img
    if [ -x "$(which boot_merger)" ]; then
        RKBIN_DIR="${STAGING_DATADIR_NATIVE}/rkbin"
        PACK_DIR="${B}/rk_pack_workspace"
        rm -rf ${PACK_DIR}
        mkdir -p ${PACK_DIR}
        cp -r ${RKBIN_DIR}/bin ${PACK_DIR}/
        cp ${RKBIN_DIR}/RKBOOT/RK3566MINIALL.ini ${PACK_DIR}/target.ini
        (cd ${PACK_DIR} && boot_merger target.ini)
        LOADER_NAME=$(grep "^PATH=" ${RKBIN_DIR}/RKBOOT/RK3566MINIALL.ini | cut -d'=' -f2 | tr -d '\r')
        [ -f "${PACK_DIR}/${LOADER_NAME}" ] && cp ${PACK_DIR}/${LOADER_NAME} ${B}/${LOADER_NAME}
    fi
}

do_deploy:append() {
    # 2. 部署 U-Boot 原生生成的 FIT 镜像 (u-boot.img)
    if [ -f "${B}/u-boot.img" ]; then
        install -m 644 ${B}/u-boot.img ${DEPLOYDIR}/uboot.img
    fi

    # 3. 部署 idbloader.img
    RKBIN_DIR="${STAGING_DATADIR_NATIVE}/rkbin"
    LOADER_NAME=$(grep "^PATH=" ${RKBIN_DIR}/RKBOOT/RK3566MINIALL.ini | cut -d'=' -f2 | tr -d '\r')
    if [ -f "${B}/${LOADER_NAME}" ]; then
        install -m 644 ${B}/${LOADER_NAME} ${DEPLOYDIR}/idbloader.img
    fi
}