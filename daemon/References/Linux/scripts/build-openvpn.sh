#!/bin/sh

cd "$(dirname "$0")"

OPEN_VPN_VER=2.4.8

# There are some dependencies required to build OpenVPN
# Here is a commands to install required packages for Ubuntu:
#
#   sudo apt-get update -y
# LibSSl headers:
#   sudo apt-get install -y libssl-dev
#
#   sudo apt-get install liblz4-dev
# If command 'route' not found, but can be installed with:
#   sudo apt install net-tools
# If configure: error: lzo enabled but missing
#   sudo apt-get install liblzo2-dev libpam0g-dev
#
# For ARM64 cross-compilation, arm64 dev libraries are required.
# archive.ubuntu.com does not serve arm64 packages - ports.ubuntu.com must be added first:
#
#   # Restrict existing sources to amd64, then add arm64 port sources:
#   sudo sed -i 's/^deb http/deb [arch=amd64] http/' /etc/apt/sources.list
#   cat <<'EOF' | sudo tee -a /etc/apt/sources.list
#   deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports focal main restricted universe multiverse
#   deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports focal-updates main restricted universe multiverse
#   deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports focal-backports main restricted universe multiverse
#   deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports focal-security main restricted universe multiverse
#   EOF
#
#   sudo dpkg --add-architecture arm64
#   sudo apt-get update
#   sudo apt-get install libssl-dev:arm64 liblz4-dev:arm64 liblzo2-dev:arm64 libpam0g-dev:arm64

# Exit immediately if a command exits with a non-zero status.
set -e

cd "$(dirname "$0")"
BASE_DIR="$(pwd)" #set base folder of script location

# --- Target architecture ---
_HOST_ARCH="$(uname -m)"
[ "$_HOST_ARCH" = "aarch64" ] && _HOST_ARCH="arm64"
[ "$_HOST_ARCH" = "x86_64"  ] && _HOST_ARCH="amd64"
ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
    amd64|arm64) ;;
    *) echo "[!] ERROR: unsupported ARCH_TARGET='$ARCH_TARGET'. Must be 'amd64' or 'arm64'."; exit 1 ;;
esac
CROSS_ARCH="${CROSS_ARCH:-}"
[ -z "$CROSS_ARCH" ] && [ "$ARCH_TARGET" != "$_HOST_ARCH" ] && CROSS_ARCH="$ARCH_TARGET"

# --- Cross-compilation flags ---
HOST_FLAG=""
CC_VAR=""
PKG_CONFIG_CROSS_DIR=""
if [ "$CROSS_ARCH" = "arm64" ]; then
    HOST_FLAG="--host=aarch64-linux-gnu"
    CC_VAR="CC=aarch64-linux-gnu-gcc"
    PKG_CONFIG_CROSS_DIR="/usr/lib/aarch64-linux-gnu/pkgconfig"
    echo "[i] Cross-compiling OpenVPN to arm64."
    echo "    Required cross-toolchain and ARM64 dev libraries. Install if missing:"
    echo "      sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu"
    echo "      sudo dpkg --add-architecture arm64 && sudo apt-get update"
    echo "      sudo apt-get install libssl-dev:arm64 liblz4-dev:arm64 liblzo2-dev:arm64 libpam0g-dev:arm64"
elif [ "$CROSS_ARCH" = "amd64" ]; then
    HOST_FLAG="--host=x86_64-linux-gnu"
    CC_VAR="CC=x86_64-linux-gnu-gcc"
    PKG_CONFIG_CROSS_DIR="/usr/lib/x86_64-linux-gnu/pkgconfig"
    echo "[i] Cross-compiling OpenVPN to amd64."
    echo "    Required cross-toolchain and amd64 dev libraries. Install if missing:"
    echo "      sudo apt-get install gcc-x86-64-linux-gnu binutils-x86-64-linux-gnu"
    echo "      sudo dpkg --add-architecture amd64"
    echo "      sudo apt-get install libssl-dev:amd64 liblz4-dev:amd64 liblzo2-dev:amd64 libpam0g-dev:amd64"
else
    echo "[i] Native build of OpenVPN for ${ARCH_TARGET}."
    echo "    Required dev libraries. Install if missing:"
    echo "      sudo apt-get install libssl-dev liblz4-dev liblzo2-dev libpam0g-dev"
fi

if [ -n "$PKG_CONFIG_CROSS_DIR" ]; then
    export PKG_CONFIG_PATH="$PKG_CONFIG_CROSS_DIR"
    export PKG_CONFIG_LIBDIR="$PKG_CONFIG_CROSS_DIR"
fi

# --- Pre-flight: verify cross-compile dev libraries are installed ---
if [ "$CROSS_ARCH" = "arm64" ]; then
    for pkg in libssl-dev:arm64 liblzo2-dev:arm64; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            echo "[!] ERROR: '$pkg' is not installed."
            echo "    Run:"
            echo "      sudo dpkg --add-architecture arm64 && sudo apt-get update"
            echo "      sudo apt-get install libssl-dev:arm64 liblz4-dev:arm64 liblzo2-dev:arm64 libpam0g-dev:arm64"
            exit 1
        fi
    done
elif [ "$CROSS_ARCH" = "amd64" ]; then
    for pkg in libssl-dev:amd64 liblzo2-dev:amd64; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            echo "[!] ERROR: '$pkg' is not installed."
            echo "    Run:"
            echo "      sudo dpkg --add-architecture amd64 && sudo apt-get update"
            echo "      sudo apt-get install libssl-dev:amd64 liblz4-dev:amd64 liblzo2-dev:amd64 libpam0g-dev:amd64"
            exit 1
        fi
    done
fi
BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/openvpn_build
INSTALL_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/openvpn_inst
echo "******** Creating work-folder (${BUILD_DIR})..."
rm -rf ${BUILD_DIR}
rm -rf ${INSTALL_DIR}

mkdir -pv ${BUILD_DIR}
mkdir -pv ${INSTALL_DIR}


echo "******** Obtaining OpenVPN sources (v${OPEN_VPN_VER})..."
cd ${BUILD_DIR}
wget https://swupdate.openvpn.org/community/releases/openvpn-$OPEN_VPN_VER.tar.gz
tar -zxf openvpn-$OPEN_VPN_VER.tar.gz
cd openvpn-$OPEN_VPN_VER

echo "******** Building (arch: ${ARCH_TARGET})..."
./configure --prefix=$INSTALL_DIR ${HOST_FLAG} ${CC_VAR}
make
make install

echo "********"
echo "DONE. Binary location: ${INSTALL_DIR}/sbin"
