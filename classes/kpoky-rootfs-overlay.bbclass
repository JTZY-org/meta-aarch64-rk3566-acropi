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

        # 1. 确保所有复制进来的可执行脚本和二进制文件拥有可执行权限 (chmod +x)
        echo "Setting executable permissions on overlay scripts and binaries..."
        find ${IMAGE_ROOTFS}/usr/bin ${IMAGE_ROOTFS}/usr/sbin ${IMAGE_ROOTFS}/etc/init.d -type f -exec chmod +x {} + 2>/dev/null || true

        # 2. 确保 /var/www 目录及其下的网页文件拥有正确的权限 (777 / chown)
        if [ -d "${IMAGE_ROOTFS}/var/www" ]; then
            echo "Setting permissions and ownership for /var/www..."
            chmod -R 777 ${IMAGE_ROOTFS}/var/www
            # 如果系统里存在 www-data 用户，则设为 www-data，否则设为 root 保证正常运作
            chown -R www-data:www-data ${IMAGE_ROOTFS}/var/www 2>/dev/null || chown -R root:root ${IMAGE_ROOTFS}/var/www
        fi
    else
        echo "Warning: Rootfs overlay source directory $OVERLAY_SRC not found."
    fi
}
