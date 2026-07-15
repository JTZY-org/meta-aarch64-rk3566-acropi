SUMMARY = "Custom rc.local scripts"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://rc.local \
    file://rc.local.init \
"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

inherit update-rc.d

# Set start priority to 99 to ensure it runs last
INITSCRIPT_NAME = "rc.local"
INITSCRIPT_PARAMS = "defaults 99"

do_install() {
    install -d ${D}${sysconfdir}/init.d
    
    # Install user script
    install -m 0755 ${UNPACKDIR}/rc.local ${D}${sysconfdir}/rc.local
    
    # Install init wrapper script
    install -m 0755 ${UNPACKDIR}/rc.local.init ${D}${sysconfdir}/init.d/rc.local
}

FILES:${PN} = "${sysconfdir}"
