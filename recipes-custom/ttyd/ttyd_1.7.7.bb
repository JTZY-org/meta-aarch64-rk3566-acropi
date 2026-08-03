SUMMARY = "Share your terminal over the web"
HOMEPAGE = "https://github.com/tsl0922/ttyd"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "https://github.com/tsl0922/ttyd/releases/download/${PV}/ttyd.aarch64;downloadfilename=ttyd-${PV}-aarch64"
SRC_URI[sha256sum] = "b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165"

#S = "${WORKDIR}"


do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/ttyd-${PV}-aarch64 ${D}${bindir}/ttyd
}

INSANE_SKIP:${PN} += "already-stripped ldflags arch"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INHIBIT_PACKAGE_STRIP = "1"
