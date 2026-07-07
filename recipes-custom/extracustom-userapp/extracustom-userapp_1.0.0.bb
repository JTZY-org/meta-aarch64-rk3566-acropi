SUMMARY = "ExtraCustom UserApp"
LICENSE = "CLOSED"

SRC_URI = "file://extracustom-userapp_1.0.0_aarch64.deb;subdir=${BP}"

inherit bin_package

# Package unversioned .so files in the main package instead of the -dev package
SOLIBS = ".so"
FILES_SOLIBSDEV = ""

# Disable QA checks for prebuilt binaries
INSANE_SKIP:${PN} += "already-stripped dev-so ldflags dev-elf"
INSANE_SKIP:${PN}-dev += "ldflags dev-elf"

INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INHIBIT_PACKAGE_STRIP = "1"

