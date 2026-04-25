SUMMARY = "Kpoky Distribution Custom Configurations"
LICENSE = "CLOSED"

inherit update-rc.d
ALLOW_EMPTY:${PN} = "1"

S = "${UNPACKDIR}"

SRC_URI = " \
    file://usb-rndis-setup.sh \
    file://usb-rndis-init \
    file://usb-network \
    file://adb-server \
    file://udhcpd.conf \
    file://migrate-irqs.sh \
"

PACKAGES =+ "${PN}-usb ${PN}-net ${PN}-adb ${PN}-irq"
INITSCRIPT_PACKAGES = "${PN}-usb ${PN}-net ${PN}-adb ${PN}-irq"

INITSCRIPT_NAME:${PN}-usb = "usb-rndis"
INITSCRIPT_PARAMS:${PN}-usb = "defaults 98"

INITSCRIPT_NAME:${PN}-net = "usb-network"
INITSCRIPT_PARAMS:${PN}-net = "defaults 99"

INITSCRIPT_NAME:${PN}-adb = "adb-server"
INITSCRIPT_PARAMS:${PN}-adb = "defaults 80"

INITSCRIPT_NAME:${PN}-irq = "migrate-irqs"
INITSCRIPT_PARAMS:${PN}-irq = "defaults 90"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/usb-rndis-setup.sh ${D}${bindir}/usb-rndis-setup.sh

    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${UNPACKDIR}/usb-rndis-init ${D}${sysconfdir}/init.d/usb-rndis
    install -m 0755 ${UNPACKDIR}/usb-network    ${D}${sysconfdir}/init.d/usb-network
    install -m 0755 ${UNPACKDIR}/adb-server     ${D}${sysconfdir}/init.d/adb-server
    install -m 0755 ${UNPACKDIR}/migrate-irqs.sh ${D}${sysconfdir}/init.d/migrate-irqs

    install -d ${D}${sysconfdir}
    install -m 0644 ${UNPACKDIR}/udhcpd.conf    ${D}${sysconfdir}/udhcpd.conf
}

FILES:${PN}-usb = "${bindir}/usb-rndis-setup.sh ${sysconfdir}/init.d/usb-rndis"
FILES:${PN}-net = "${sysconfdir}/init.d/usb-network ${sysconfdir}/udhcpd.conf"
FILES:${PN}-adb = "${sysconfdir}/init.d/adb-server"
FILES:${PN}-irq = "${sysconfdir}/init.d/migrate-irqs"

RDEPENDS:${PN} += "${PN}-usb ${PN}-net ${PN}-adb ${PN}-irq"

RDEPENDS:${PN}-usb += "busybox kernel-module-libcomposite kernel-module-u-ether kernel-module-usb-f-rndis"
RDEPENDS:${PN}-net += "busybox"
RDEPENDS:${PN}-adb += "android-tools"

INSANE_SKIP:${PN} += "build-deps"
