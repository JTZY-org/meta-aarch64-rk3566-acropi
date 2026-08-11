SUMMARY = "APS CLI and calibration tools"
LICENSE = "CLOSED"

# Force BitBake to re-parse this recipe every time, preventing caching of the dynamically scanned .deb filename
BB_DONT_CACHE = "1"

# Inline Python to find the .deb file in files/ directory dynamically
def get_latest_deb(d):
    import glob
    import os
    this_dir = d.getVar('THISDIR')
    files_dir = os.path.join(this_dir, 'files')
    debs = glob.glob(os.path.join(files_dir, 'ruaps_cli_*_aarch64.deb'))
    if debs:
        # Sort by modification time to get the newest file
        debs.sort(key=os.path.getmtime)
        return os.path.basename(debs[-1])
    return "ruaps_cli_aarch64.deb"

DEB_FILE = "${@get_latest_deb(d)}"

SRC_URI = "file://${DEB_FILE};subdir=${BP}"

# Extract version from filename (e.g. ruaps_cli_bf56633_aarch64.deb -> bf56633)
def get_deb_version(deb_file):
    import re
    match = re.search(r'ruaps_cli_(.*)_aarch64\.deb', deb_file)
    if match:
        return match.group(1)
    return "1.0"

PV = "${@get_deb_version('${DEB_FILE}')}"

inherit bin_package

# Disable QA checks for prebuilt binaries
INSANE_SKIP:${PN} += "already-stripped ldflags"

INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INHIBIT_PACKAGE_STRIP = "1"
