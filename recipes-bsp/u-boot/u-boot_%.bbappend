FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "git://github.com/rockchip-linux/u-boot.git;protocol=https;branch=next-dev \
           file://0000-fix-buildbl31-script.patch \
           file://0001-add-RK809-PMIC.patch \
           file://parameter.txt \
           file://boot.cfg"

SRCREV = "${AUTOREV}"

UBOOT_MACHINE = "rk3568_defconfig"

COMPATIBLE_MACHINE = "rk3566-acropi"

LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

EXTRA_OEMAKE:append = " KCFLAGS='-Wno-error'"

DEPENDS += "rkbin-native u-boot-tools-native python3-native"

export BL31 = "${STAGING_DATADIR_NATIVE}/rkbin/bin/rk35/rk3568_bl31_v1.43.elf"
export TEE = "${STAGING_DATADIR_NATIVE}/rkbin/bin/rk35/rk3568_bl32_v2.10.bin"

do_configure:append() {
    cat "${UNPACKDIR}/boot.cfg" >> "${B}/.config"
}

do_compile:prepend() {
    # Link BL31 ELF to build directory
    if [ -f "${BL31}" ]; then
        ln -sf ${BL31} ${B}/bl31.elf
    else
        echo "Error: BL31 binary not found at ${BL31}"
        exit 1
    fi
    
    # Link real TEE binary to build directory (FIT script expects tee.bin)
    if [ -f "${TEE}" ]; then
        ln -sf ${TEE} ${B}/tee.bin
    else
        echo "Error: TEE binary not found at ${TEE}. A real TEE is required for successful boot."
        exit 1
    fi

    # Pre-generate DTBs
    oe_runmake dtbs

    # Create u-boot.dtb symlink required by FIT generation scripts
    if [ -f "${B}/dts/dt.dtb" ]; then
        ln -sf dts/dt.dtb ${B}/u-boot.dtb
    fi
}

UBOOT_MAKE_TARGET = "u-boot.itb"

do_compile:append() {
    # Generate loader using Rockchip boot_merger
    if [ -x "$(which boot_merger)" ]; then
        RKBIN_DIR="${STAGING_DATADIR_NATIVE}/rkbin"
        PACK_DIR="${B}/rk_pack_workspace"
        rm -rf ${PACK_DIR}
        mkdir -p ${PACK_DIR}
        cp -r ${RKBIN_DIR}/bin ${PACK_DIR}/
        cp ${RKBIN_DIR}/RKBOOT/RK3566MINIALL.ini ${PACK_DIR}/target.ini
        (cd ${PACK_DIR} && boot_merger target.ini)
        
        # Extract the original loader filename
        ORIG_LOADER_NAME=$(grep "^PATH=" ${RKBIN_DIR}/RKBOOT/RK3566MINIALL.ini | cut -d'=' -f2 | tr -d '\r')
        if [ -f "${PACK_DIR}/${ORIG_LOADER_NAME}" ]; then
            cp ${PACK_DIR}/${ORIG_LOADER_NAME} ${B}/${ORIG_LOADER_NAME}
        fi
    fi
}

do_deploy:append() {
    # 1. Deploy the FIT image as uboot.img
    if [ -f "${B}/u-boot.itb" ]; then
        install -m 644 ${B}/u-boot.itb ${DEPLOYDIR}/uboot.img
    fi

    # 2. Deploy the loader using only its original Rockchip name
    RKBIN_DIR="${STAGING_DATADIR_NATIVE}/rkbin"
    ORIG_LOADER_NAME=$(grep "^PATH=" ${RKBIN_DIR}/RKBOOT/RK3566MINIALL.ini | cut -d'=' -f2 | tr -d '\r')
    if [ -f "${B}/${ORIG_LOADER_NAME}" ]; then
        install -m 644 ${B}/${ORIG_LOADER_NAME} ${DEPLOYDIR}/${ORIG_LOADER_NAME}
    fi

    # 3. Deploy parameter.txt - locate it dynamically in WORKDIR
    if [ -f "${WORKDIR}/parameter.txt" ]; then
        install -m 644 ${WORKDIR}/parameter.txt ${DEPLOYDIR}/parameter.txt
    elif [ -f "${S}/../parameter.txt" ]; then
        install -m 644 ${S}/../parameter.txt ${DEPLOYDIR}/parameter.txt
    fi

}