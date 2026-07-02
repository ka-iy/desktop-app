#!/bin/sh

# Build IVPN Electron UI and package as DEB/RPM.
# Calls compile-ui.sh (electron-builder), then fpm.
#
# Usage:
#   ./build.sh [-v <version>]
#
# Environment variables:
#   ARCH_TARGET   Target architecture: amd64 (default on x86_64 host) or arm64.
#                 Output packages: _out_bin/<arch>/ivpn-ui_<ver>_<arch>.deb/.rpm

# To be able to build packages the 'fpm' tool shall be installed
# (https://fpm.readthedocs.io/en/latest/installing.html)

# Useful commands (Ubuntu):
#
# To view *.deb package content:
#     dpkg -c ivpn_1.0_amd64.deb
# List of installet packets:
#     dpkg --list [<mask>]
# Install package:
#     apt-get install <pkg-name>
# Remove packet:
#     dpkg --remove <packetname>
# Remove (2):
#     apt-get remove ivpn
#     apt-get purge curl
#     apt-get autoremove
# Remove repository (https://www.ostechnix.com/how-to-delete-a-repository-and-gpg-key-in-ubuntu/):
#     add-apt-repository -r ppa:wireguard/wireguard
#     apt update
# List of services:
#     systemctl --type=service
# Start service:
#     systemctl start ivpn-service
# Remove BROKEN package (which is unable to uninstall by normal ways)
#     sudo mv /var/lib/dpkg/info/ivpn.* /tmp/
#     sudo dpkg --remove --force-remove-reinstreq ivpn

cd "$(dirname "$0")"

# check result of last executed command
CheckLastResult()
{
  if ! [ $? -eq 0 ]
  then #check result of last command
    if [ -n "$1" ]
    then
      echo $1
    else
      echo "FAILED"
    fi
    exit 1
  fi
}

SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# --- Target architecture ---
_HOST_ARCH="$(uname -m)"
[ "$_HOST_ARCH" = "aarch64" ] && _HOST_ARCH="arm64"
[ "$_HOST_ARCH" = "x86_64"  ] && _HOST_ARCH="amd64"
export ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
    amd64|arm64) ;;
    *) echo "[!] ERROR: unsupported ARCH_TARGET='$ARCH_TARGET'. Must be 'amd64' or 'arm64'."; exit 1 ;;
esac

# ARCH follows electron-builder's directory naming convention (x64/arm64)
ARCH="x64"
[ "$ARCH_TARGET" = "arm64" ] && ARCH="arm64"

# fpm architecture names differ by package type
DEB_ARCH="amd64"
RPM_ARCH="x86_64"
if [ "$ARCH_TARGET" = "arm64" ]; then
    DEB_ARCH="arm64"
    RPM_ARCH="aarch64"
fi

OUT_DIR="$SCRIPT_DIR/_out_bin/${ARCH_TARGET}"
APP_UNPACKED_DIR="$SCRIPT_DIR/../../dist/linux-unpacked"
APP_UNPACKED_DIR_ARCH="$SCRIPT_DIR/../../dist/linux-${ARCH}-unpacked"
APP_BIN_DIR="$SCRIPT_DIR/../../dist/bin"
IVPN_DESKTOP_UI2_SOURCES="$SCRIPT_DIR/../../"

# In Snapcraft/LXD builds ensure npm subprocesses resolve the same Node runtime.
if [ -n "$SNAPCRAFT_PART_INSTALL" ] && [ -d "/snap/node/current/bin" ]; then
  export PATH="/snap/node/current/bin:$PATH"
fi

# ---------------------------------------------------------
# version info variables
VERSION=""

# reading version info from arguments
while getopts ":v:" opt; do
  case $opt in
    v) VERSION="$OPTARG"
    ;;
  esac
done

if [ -z "$VERSION" ]
then
  # Version was not provided by argument.
  # Intialize $VERSION by the data from of command: '../../package.json'
  VERSION="$(awk -F: '/"version"/ { gsub(/[" ,\n\r]/, "", $2); print $2 }' ../../package.json)"
  if [ -n "$VERSION" ]
  then
    echo "[ ] Compiling IVPN UI v${VERSION}"
  else    
    echo "Usage:"
    echo "    $0 -v <version>"
    exit 1
  fi
fi

echo "Architecture: $ARCH"
echo "======================================================"
echo "============ Building UI binary ======================"
echo "======================================================"

if [ -d $APP_UNPACKED_DIR ]; then
  echo "[+] Removing: $APP_UNPACKED_DIR"
  rm -fr "$APP_UNPACKED_DIR"
fi
if [ -d $APP_UNPACKED_DIR_ARCH ]; then
  echo "[+] Removing: $APP_UNPACKED_DIR_ARCH"
  rm -fr "$APP_UNPACKED_DIR_ARCH"
fi

if [ -d $APP_BIN_DIR ]; then
  echo "[+] Removing: $APP_BIN_DIR"
  rm -fr "$APP_BIN_DIR"
fi

cat "$IVPN_DESKTOP_UI2_SOURCES/package.json" | grep \"version\" | grep \"$VERSION\"
CheckLastResult "ERROR: Please set correct version in file '${IVPN_DESKTOP_UI2_SOURCES}package.json'"

echo "*** Installing NPM molules ... ***"
cd $IVPN_DESKTOP_UI2_SOURCES
CheckLastResult
npm install
CheckLastResult
cd $SCRIPT_DIR
CheckLastResult

echo "*** Building Electron app ... ***"
$SCRIPT_DIR/compile-ui.sh
CheckLastResult

if [ -d $APP_UNPACKED_DIR_ARCH ]; then
    # for non-standard architecture we must use the architecture-dependend path
    echo "Info: Non 'default' architecture!" 
    APP_UNPACKED_DIR=$APP_UNPACKED_DIR_ARCH
fi
if [ -d $APP_UNPACKED_DIR ]; then
    echo "[ ] Exist: $APP_UNPACKED_DIR"
else
  echo "[!] Folder not exists: '$APP_UNPACKED_DIR'"
  echo "    Build IVPN UI project (do not forget to set correct version for it in 'package.json')"
  exit 1
fi
if [ -f "$APP_UNPACKED_DIR/ivpn-ui" ]; then
    echo "[ ] Exist: $APP_UNPACKED_DIR/ivpn-ui"
else
  echo "[!] File not exists: '$APP_UNPACKED_DIR/ivpn-ui'"
  echo "    Build IVPN UI project (do not forget to set correct version for it in 'package.json')"
  exit 1
fi

echo "[ ] Renaming: '$APP_UNPACKED_DIR' -> '$APP_BIN_DIR'"
mv $APP_UNPACKED_DIR $APP_BIN_DIR
CheckLastResult

if [ -n "$SNAPCRAFT_PART_INSTALL" ]; then
  echo "! SNAPCRAFT_PART_INSTALL detected !"
    echo "! DEB/RPM packages build skipped !"
    exit 0
fi

echo "======================================================"
echo "============== Building packages ====================="
echo "======================================================"

set -e

TMPDIR="$SCRIPT_DIR/_tmp"
if [ -d "$TMPDIR" ]; then rm -Rf $TMPDIR; fi
mkdir -p $TMPDIR

CreatePackage()
{
  PKG_TYPE=$1
  EXTRA_ARGS=$2

  cd $TMPDIR

  # Scripts order is different for different types of packages
  # DEB Install:
  #   (On Install)      (On Upgrade)
  #                     before_remove
  #   before_install    before_upgrade\before_install
  #                     after_remove
  #   after_install     after_upgrade\after_install
  #
  # DEB remove
  #   before_remove
  #   after_remove
  #
  # RPM Install:
  #   (On Install)      (On Upgrade)
  #   before_install    before_upgrade\before_install
  #   after_install     after_upgrade\after_install
  #                     before_remove
  #                     after_remove
  #
  # RPM remove
  #   before_remove
  #   after_remove
  #
  # NOTE! 'remove' scripts is using from old version!
  #
  # EXAMPLES:
  #
  # DEB
  # (Useful link: https://wiki.debian.org/MaintainerScripts)
  #
  # DEB (apt) Install3.3.30:
  #   [*] Before install (3.3.30 : deb : install)
  #   [*] After install (3.3.30 : deb : configure)
  # DEB (apt) Upgrade 3.3.20->3.3.30:
  #   [*] Before remove (3.3.20 : deb : upgrade)
  #   [*] Before install (3.3.30 : deb : upgrade)
  #   [*] After remove (3.3.20 : deb : upgrade)
  #   [*] After install (3.3.30 : deb : configure)
  # DEB (apt) Remove:
  #   [*] Before remove (3.3.20 : deb : remove)
  #   [*] After remove (3.3.20 : deb : remove)
  #
  # RPM
  # (Useful link: https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/)
  #   When scriptlets are called, they will be supplied with an argument.
  #   This argument, accessed via $1 (for shell scripts) is the number of packages of this name
  #   which will be left on the system when the action completes.
  #
  # RPM (dnf) install:
  #   [*] Before install (3.3.30 : rpm : 1)
  #   [*] After install (3.3.30 : rpm : 1)
  # RPM (dnf) upgrade:
  #   [*] Before install (3.3.30 : rpm : 2)
  #   [*] After install (3.3.30 : rpm : 2)
  #   [*] Before remove (3.3.20 : rpm : 1)
  #   [*] After remove (3.3.20 : rpm : 1)
  # RPM (dnf) remove:
  #   [*] Before remove (3.3.30 : rpm : 0)
  #   [*] After remove (3.3.30 : rpm : 0)

  _PKG_ARCH=$DEB_ARCH
  [ "$PKG_TYPE" = "rpm" ] && _PKG_ARCH=$RPM_ARCH

  fpm -d ivpn $EXTRA_ARGS \
    --architecture $_PKG_ARCH \
    --rpm-rpmbuild-define "_build_id_links none" \
    --deb-no-default-config-files -s dir -t $PKG_TYPE -n ivpn-ui -v $VERSION --url https://www.ivpn.net --license "GNU GPL3" \
    --template-scripts --template-value pkg=$PKG_TYPE --template-value version=$VERSION \
    --vendor "IVPN Limited" --maintainer "IVPN Limited" \
    --description "$(printf "UI client for IVPN service (https://www.ivpn.net)\nGraphical interface v$VERSION.")" \
    --before-install "$SCRIPT_DIR/package_scripts/before-install.sh" \
    --after-install "$SCRIPT_DIR/package_scripts/after-install.sh" \
    --before-remove "$SCRIPT_DIR/package_scripts/before-remove.sh" \
    --after-remove "$SCRIPT_DIR/package_scripts/after-remove.sh" \
    $SCRIPT_DIR/ui/IVPN.desktop=/opt/ivpn/ui/IVPN.desktop \
    $SCRIPT_DIR/ui/ivpnicon.svg=/opt/ivpn/ui/ivpnicon.svg \
    $APP_BIN_DIR=/opt/ivpn/ui/
}

echo '---------------------------'
echo "DEB package..."
# to add dependency from another packet add extra arg "-d", example: "-d obfsproxy"
CreatePackage "deb"

echo '---------------------------'
echo "RPM package..."
CreatePackage "rpm"

echo '---------------------------'
echo "Copying compiled pachages to '$OUT_DIR'..."
mkdir -p $OUT_DIR
yes | cp -f $TMPDIR/*.* $OUT_DIR

set +e
