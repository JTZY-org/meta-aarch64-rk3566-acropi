SUMMARY = "Network sniffer tool"
LICENSE = "CLOSED"

SRC_URI = "file://sinffer_0.1.0_aarch64.deb;subdir=${BP}"

inherit bin_package

# Disable QA checks for prebuilt binaries
INSANE_SKIP:${PN} += "already-stripped ldflags"

INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INHIBIT_PACKAGE_STRIP = "1"
