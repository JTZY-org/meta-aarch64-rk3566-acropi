FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI = "git://github.com/rockchip-linux/u-boot.git;protocol=https;branch=next-dev"

SRCREV = "${AUTOREV}"

UBOOT_MACHINE = "rk3568_defconfig"

COMPATIBLE_MACHINE = "rk3566-acropi"

LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

EXTRA_OEMAKE:append = " KCFLAGS='-Wno-error=maybe-uninitialized -Wno-error=enum-int-mismatch -Wno-error=unused-variable'"

DEPENDS += "rkbin-native u-boot-tools-native python3-native"

export BL31 = "${STAGING_DATADIR_NATIVE}/rkbin/bin/rk35/rk3568_bl31_v1.43.elf"
export TEE = "${STAGING_DATADIR_NATIVE}/rkbin/bin/rk35/rk3568_bl32_v2.10.bin"

# Fix scripts in source tree to support out-of-tree build and Python 3
do_patch:append() {
    bb.note("Patching Rockchip scripts for out-of-tree build and Python 3")
    
    import subprocess
    s = d.getVar('S')
    
    # 1. Remove leading ./ from source commands to support absolute paths
    subprocess.run(['sed', '-i', 's|source \./${srctree}|source ${srctree}|g', f"{s}/arch/arm/mach-rockchip/make_fit_atf.sh"])
    subprocess.run(['sed', '-i', 's|source \./${srctree}|source ${srctree}|g', f"{s}/arch/arm/mach-rockchip/fit_nodes.sh"])
    
    # 2. Update fit_args.sh to read configuration from the build directory instead of source directory
    subprocess.run(['sed', '-i', 's|^srctree=$PWD|#srctree=$PWD|g', f"{s}/arch/arm/mach-rockchip/fit_args.sh"])
    subprocess.run(['sed', '-i', 's|${srctree}/include/autoconf.mk|./include/autoconf.mk|g', f"{s}/arch/arm/mach-rockchip/fit_args.sh"])
    
    # 3. Fix include paths in fit_nodes.sh as well
    subprocess.run(['sed', '-i', 's|${srctree}/include/autoconf.mk|./include/autoconf.mk|g', f"{s}/arch/arm/mach-rockchip/fit_nodes.sh"])
    
    # 4. Patch Python 2 to Python 3 in decode_bl31.py
    subprocess.run(['sed', '-i', 's|python2|python3|g', f"{s}/arch/arm/mach-rockchip/decode_bl31.py"])

    # 5. Append custom name to the main Makefile version
    subprocess.run(['sed', '-i', 's|^EXTRAVERSION =|EXTRAVERSION = -BUILD BY TSKangetu|g', f"{s}/Makefile"])
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

    # 3. Deploy parameter_gpt.txt if it exists in the project root
    if [ -f "${TOPDIR}/../parameter_gpt.txt" ]; then
        install -m 644 ${TOPDIR}/../parameter_gpt.txt ${DEPLOYDIR}/parameter.txt
    fi

    # 4. Clean up unnecessary standard U-Boot artifacts
    rm -f ${DEPLOYDIR}/u-boot.bin
    rm -f ${DEPLOYDIR}/u-boot-*.bin
    rm -f ${DEPLOYDIR}/u-boot-initial-env*
    rm -f ${DEPLOYDIR}/u-boot.img-*
}