# rk-image.bbclass
#
# This class provides support for generating Rockchip update.img files
# using the official C-based afptool and img_maker.

inherit image_types

# We need rockchip-pack-tools-native to pack the image
do_image_rkimg[depends] += "rockchip-pack-tools-native:do_populate_sysroot"

# rkimg depends on both squashfs and ext4 rootfs being ready
IMAGE_TYPEDEP:rkimg = "squashfs ext4"

IMAGE_CMD:rkimg () {
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

    pack_update_image() {
        local fs_type=$1
        local suffix=$2
        local rootfs_src="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.${fs_type}"
        
        # If the file doesn't exist under link name, search via wildcard
        if [ ! -f "$rootfs_src" ]; then
            rootfs_src=$(ls -t ${IMGDEPLOYDIR}/${IMAGE_BASENAME}-${MACHINE}.*.${fs_type} 2>/dev/null | head -n 1)
        fi
        
        if [ -z "$rootfs_src" ] || [ ! -f "$rootfs_src" ]; then
            bbnote "Skipping ${fs_type} update image generation: source file not found"
            return 0
        fi

        bbnote "Generating ${fs_type} update image..."
        local workspace="${WORKDIR}/rk_workspace_${fs_type}"
        rm -rf ${workspace}
        mkdir -p ${workspace}

        # Copy necessary components to the workspace
        cp "${DEPLOY_DIR_IMAGE}/parameter.txt" "${workspace}/parameter"
        cp "${DEPLOY_DIR_IMAGE}/uboot.img" "${workspace}/uboot.img"
        cp "${DEPLOY_DIR_IMAGE}/boot.img" "${workspace}/boot.img"
        cp "$rootfs_src" "${workspace}/rootfs.img"

        # Calculate size of rootfs.img and dynamically rewrite parameter partition table
        local rootfs_size=$(stat -c%s "${workspace}/rootfs.img")
        local rootfs_sectors=$(expr $rootfs_size / 512)
        
        # Align to 4MB boundary (8192 sectors)
        local align_sectors=8192
        rootfs_sectors=$(expr \( \( $rootfs_sectors + $align_sectors - 1 \) / $align_sectors \) \* $align_sectors)
        
        # Calculate data partition start sector (rootfs offset is 0x40000 = 262144 sectors)
        local rootfs_start=262144
        local data_start=$(expr $rootfs_start + $rootfs_sectors)
        
        local rootfs_hex=$(printf "0x%08x" ${rootfs_sectors})
        local data_start_hex=$(printf "0x%08x" ${data_start})
        
        bbnote "Dynamically updating parameter file with calculated rootfs size: ${rootfs_hex} and data start: ${data_start_hex}"
        sed -i "s/0x[0-9a-fA-F]*@0x00040000(rootfs),-@0x[0-9a-fA-F]*(data:grow)/${rootfs_hex}@0x00040000(rootfs),-@${data_start_hex}(data:grow)/" "${workspace}/parameter"

        # Create package-file
        cat > ${workspace}/package-file <<EOF
# VERSION: 0.1
package-file
parameter   parameter
uboot       uboot.img
boot        boot.img
rootfs      rootfs.img
EOF

        # 1. Pack with afptool
        bbnote "Packing with afptool for ${fs_type}..."
        (cd ${workspace} && afptool -pack . intermediate.img)

        # 2. Add loader with rkImageMaker
        local output_img="${IMGDEPLOYDIR}/${IMAGE_NAME}${suffix}.update.img"
        local output_link="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}${suffix}.update.img"

        bbnote "Generating final update.img with rkImageMaker for ${fs_type}..."
        rkImageMaker -RK3568 "${DEPLOY_DIR_IMAGE}/$LOADER_BIN" ${workspace}/intermediate.img "$output_img" -os_type:androidos
        ln -sf $(basename "$output_img") "$output_link"

        # 3. Compress update.img with 7z
        bbnote "Compressing update.img with 7z (maximum compression mx=9) for ${fs_type}..."
        rm -f "${output_img}.7z"
        7z a -mx=9 "${output_img}.7z" "$output_img"
        ln -sf $(basename "${output_img}.7z") "${output_link}.7z"
    }

    # Generate standard SquashFS update image (default output suffix "")
    pack_update_image squashfs ""

    # Generate traditional Ext4 update image (suffix "-ext4")
    pack_update_image ext4 "-ext4"
}

# Ensure all dependencies are deployed before we try to pack
do_image_rkimg[depends] += " \
    virtual/kernel:do_deploy \
    virtual/bootloader:do_deploy \
"
