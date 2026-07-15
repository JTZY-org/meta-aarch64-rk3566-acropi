# kpoky-rootfs-overlay.bbclass
# 
# This class implements a late-stage rootfs overlay mechanism.
# It copies files from the meta layer's permanent overlay directory
# to the image rootfs at the very end of the post-processing phase.

ROOTFS_POSTPROCESS_COMMAND += "rootfs_overlay_copy_last; setup_rootfs_overlay_init; "

rootfs_overlay_copy_last() {
    # Ensure META_RK3566_ACROPI_BASE variable is defined
    # If not, fallback to relative logic or default paths
    OVERLAY_SRC="${META_RK3566_ACROPI_BASE}/recipes-core/kpoky-config/files/files"
    
    if [ -d "$OVERLAY_SRC" ]; then
        echo "Applying permanent rootfs overlay from $OVERLAY_SRC..."
        # Use -af to preserve attributes and force overwrite
        cp -af "$OVERLAY_SRC"/* ${IMAGE_ROOTFS}/

        # 1. Ensure copied scripts and binaries have executable permissions
        echo "Setting executable permissions on overlay scripts and binaries..."
        find ${IMAGE_ROOTFS}/usr/bin ${IMAGE_ROOTFS}/usr/sbin ${IMAGE_ROOTFS}/etc/init.d -type f -exec chmod +x {} + 2>/dev/null || true

        # 2. Ensure /var/www and web files have correct permissions
        if [ -d "${IMAGE_ROOTFS}/var/www" ]; then
            echo "Setting permissions and ownership for /var/www..."
            chmod -R 777 ${IMAGE_ROOTFS}/var/www
            # Use www-data owner if exists, otherwise fallback to root
            chown -R www-data:www-data ${IMAGE_ROOTFS}/var/www 2>/dev/null || chown -R root:root ${IMAGE_ROOTFS}/var/www
        fi
    else
        echo "Warning: Rootfs overlay source directory $OVERLAY_SRC not found."
    fi
}

python setup_rootfs_overlay_init() {
    import os
    import shutil

    image_rootfs = d.getVar('IMAGE_ROOTFS')
    
    # Pre-create mount points for read-only system to prevent read-only errors on boot
    for dir_path in ['mnt/rom', 'mnt/overlay', 'new_root']:
        os.makedirs(os.path.join(image_rootfs, dir_path), exist_ok=True)

    # Ensure /run is a real directory and /var/run points to it, matching modern layouts
    run_dir = os.path.join(image_rootfs, 'run')
    if os.path.islink(run_dir):
        os.unlink(run_dir)
    os.makedirs(run_dir, exist_ok=True)

    var_run_dir = os.path.join(image_rootfs, 'var/run')
    if os.path.islink(var_run_dir) or os.path.exists(var_run_dir):
        try:
            if os.path.islink(var_run_dir):
                os.unlink(var_run_dir)
            else:
                shutil.rmtree(var_run_dir)
        except Exception:
            pass
    try:
        os.symlink('/run', var_run_dir)
    except Exception:
        pass

    # Fix 'Configuring network interfaces... ip: SIOCGIFFLAGS: No such device' warning
    interfaces_path = os.path.join(image_rootfs, 'etc/network/interfaces')
    if os.path.exists(interfaces_path):
        with open(interfaces_path, 'r') as f:
            lines = f.readlines()
        new_lines = []
        for line in lines:
            if 'eth0' in line:
                continue
            new_lines.append(line)
        with open(interfaces_path, 'w') as f:
            f.writelines(new_lines)

    init_path = os.path.join(image_rootfs, 'sbin/init')
    init_real_path = os.path.join(image_rootfs, 'sbin/init.real')
    init_wrapper_path = os.path.join(image_rootfs, 'sbin/init.wrapper')

    # 1. Rename the real init binary
    if os.path.islink(init_path):
        link_target = os.readlink(init_path)
        if link_target.startswith('/'):
            target_path = os.path.join(image_rootfs, link_target.lstrip('/'))
        else:
            target_path = os.path.join(os.path.dirname(init_path), link_target)
        shutil.move(target_path, init_real_path)
        os.unlink(init_path)
    elif os.path.exists(init_path):
        shutil.move(init_path, init_real_path)

    # 2. Replace /sbin/init with init.wrapper copied via files/files
    if os.path.exists(init_wrapper_path):
        shutil.move(init_wrapper_path, init_path)
        os.chmod(init_path, 0o755)
    else:
        raise RuntimeError("setup_rootfs_overlay_init: init.wrapper not found in rootfs sbin/")
}
