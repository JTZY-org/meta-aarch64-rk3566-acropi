# rk-image.bbclass
#
# This class provides support for generating Rockchip update.img files
# using the official C-based afptool and img_maker.

inherit image_types

# We need rockchip-pack-tools-native to pack the image
do_image_rkimg[depends] += "rockchip-pack-tools-native:do_populate_sysroot"

# rkimg depends on the ext4 rootfs being ready
IMAGE_TYPEDEP:rkimg = "ext4"

IMAGE_CMD:rkimg () {
    # Prepare a temporary workspace for packing
    # Change the name to avoid Pseudo path mismatch with old state
    RK_WORKSPACE="${WORKDIR}/rk_image_workspace"
    rm -rf ${RK_WORKSPACE}
    mkdir -p ${RK_WORKSPACE}

    # Identify the loader binary
    LOADER_BIN="${RK_LOADER_BIN}"
    if [ -z "$LOADER_BIN" ]; then
        # Fallback to wildcard search if not explicitly defined
        LOADER_BIN=$(ls ${DEPLOY_DIR_IMAGE}/rk356x_spl_loader_*.bin | head -n 1 | xargs basename)
    fi

    if [ ! -f "${DEPLOY_DIR_IMAGE}/$LOADER_BIN" ]; then
        bberror "Rockchip loader binary ($LOADER_BIN) not found in ${DEPLOY_DIR_IMAGE}"
        exit 1
    fi

    # Copy all necessary components to the workspace
    # Official tools usually don't care about extensions, but partition names must match parameter.txt
    cp "${DEPLOY_DIR_IMAGE}/parameter.txt" "${RK_WORKSPACE}/parameter"
    cp "${DEPLOY_DIR_IMAGE}/uboot.img" "${RK_WORKSPACE}/uboot.img"
    cp "${DEPLOY_DIR_IMAGE}/boot.img" "${RK_WORKSPACE}/boot.img"
    
    # Locate the ext4 rootfs
    ROOTFS_IMG="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.ext4"
    if [ ! -f "$ROOTFS_IMG" ]; then
        ROOTFS_IMG=$(ls -t ${IMGDEPLOYDIR}/${IMAGE_BASENAME}-${MACHINE}.*.ext4 | head -n 1)
    fi

    if [ -f "$ROOTFS_IMG" ]; then
        cp "$ROOTFS_IMG" "${RK_WORKSPACE}/rootfs.img"
    else
        bberror "Rootfs image not found in ${IMGDEPLOYDIR}"
        exit 1
    fi

    # Create the official package-file format
    # Columns: [Partition Name] [Relative Path]
    cat > ${RK_WORKSPACE}/package-file <<EOF
# VERSION: 0.1
package-file
parameter   parameter
uboot       uboot.img
boot        boot.img
rootfs      rootfs.img
EOF

    # 1. Pack with afptool
    bbnote "Packing with afptool..."
    (cd ${RK_WORKSPACE} && afptool -pack . intermediate.img)

    # 2. Add loader with rkImageMaker
    # RK3566/RK3568 use the same packing format.
    # Usage: rkImageMaker [chiptype] [loader] [input image] [output image] [flags]
    bbnote "Generating final update.img with rkImageMaker..."
    rkImageMaker -RK3568 "${DEPLOY_DIR_IMAGE}/$LOADER_BIN" ${RK_WORKSPACE}/intermediate.img ${IMGDEPLOYDIR}/${IMAGE_NAME}.update.img -os_type:androidos

    # Create a symlink for the latest update image
    ln -sf ${IMAGE_NAME}.update.img ${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.update.img
}

# Ensure all dependencies are deployed before we try to pack
do_image_rkimg[depends] += " \
    virtual/kernel:do_deploy \
    virtual/bootloader:do_deploy \
"
