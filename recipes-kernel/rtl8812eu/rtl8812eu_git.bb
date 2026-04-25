SUMMARY = "Realtek 8812EU/8821EU USB WiFi driver"
HOMEPAGE = "https://github.com/TSKangetsu/fvck-realtek-88x2eu"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://Makefile;md5=cc9b8be92c48ef1f1b4afdf04d626216"

SRC_URI = "git://github.com/TSKangetsu/fvck-realtek-88x2eu.git;protocol=https;branch=master"
SRCREV = "e5da2b7c907ff07c7adb21c9bc0c2b82786771e0"

S = "${WORKDIR}/git"

inherit module

EXTRA_OEMAKE = " \
    -C ${STAGING_KERNEL_DIR} \
    M=${S} \
    CONFIG_RTL8822EU=m \
"

MAKE_TARGETS = "modules"
MODULES_INSTALL_TARGET = "modules_install"

do_configure:prepend() {
    # Fix RHEL macro syntax errors on standard Linux kernels (like 6.1)
    sed -i '1i #ifndef RHEL_RELEASE_CODE\n#define RHEL_RELEASE_CODE 0\n#define RHEL_RELEASE_VERSION(a,b) 0\n#endif' ${S}/os_dep/linux/ioctl_cfg80211.c
}

PROVIDES += "kernel-module-8812eu"

# Add a configuration file for module parameters
do_install:append() {
    install -d ${D}${sysconfdir}/modprobe.d
    echo "options 8812eu rtw_tx_pwr_by_rate=0 rtw_tx_pwr_lmt_enable=0" > ${D}${sysconfdir}/modprobe.d/8812eu.conf
}

FILES:${PN} += "${sysconfdir}/modprobe.d/8812eu.conf"
