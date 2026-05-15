# kpoky-rootfs-overlay.bbclass
# 
# This class implements a late-stage rootfs overlay mechanism.
# It copies files from the meta layer's permanent overlay directory
# to the image rootfs at the very end of the post-processing phase.

ROOTFS_POSTPROCESS_COMMAND += "rootfs_overlay_copy_last; "

rootfs_overlay_copy_last() {
    # 确保变量 META_RK3566_ACROPI_BASE 已经定义
    # 如果没有定义，尝试从 layer.conf 的逻辑中推导或使用默认相对路径
    OVERLAY_SRC="${META_RK3566_ACROPI_BASE}/recipes-core/kpoky-config/files/files"
    
    if [ -d "$OVERLAY_SRC" ]; then
        echo "Applying permanent rootfs overlay from $OVERLAY_SRC..."
        # 使用 -af 保持权限和属性，强制覆盖
        cp -af "$OVERLAY_SRC"/* ${IMAGE_ROOTFS}/
    else
        echo "Warning: Rootfs overlay source directory $OVERLAY_SRC not found."
    fi
}
