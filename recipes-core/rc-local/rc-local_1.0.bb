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

# 设置启动优先级为 99，确保最后运行
INITSCRIPT_NAME = "rc.local"
INITSCRIPT_PARAMS = "defaults 99"

do_install() {
    install -d ${D}${sysconfdir}/init.d
    
    # 安装用户脚本
    install -m 0755 ${UNPACKDIR}/rc.local ${D}${sysconfdir}/rc.local
    
    # 安装 init 包装脚本
    install -m 0755 ${UNPACKDIR}/rc.local.init ${D}${sysconfdir}/init.d/rc.local
}

FILES:${PN} = "${sysconfdir}"
