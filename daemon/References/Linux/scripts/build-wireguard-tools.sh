#!/bin/sh

# Build wireguard-tools (wg, wg-quick) from source.
#
# Usage:
#   ./build-wireguard-tools.sh
#
# Environment variables:
#   ARCH_TARGET   Target architecture: amd64 (default on x86_64 host) or arm64.
#   CROSS_ARCH    Cross-compiler selector (auto-derived from ARCH_TARGET).
#                 Output: ../_deps/<arch>/wireguard-tools_inst/

WG_TOOLS_VER=v1.0.20260223 # https://git.zx2c4.com/wireguard-tools/

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
MAKE_VARS=""
if [ "$CROSS_ARCH" = "arm64" ]; then
    MAKE_VARS="CC=aarch64-linux-gnu-gcc ARCH=arm64"
    echo "[i] Cross-compiling wireguard-tools to arm64."
    echo "    Cross-toolchain required. Install if missing:"
    echo "      sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu"
elif [ "$CROSS_ARCH" = "amd64" ]; then
    MAKE_VARS="CC=x86_64-linux-gnu-gcc ARCH=x86_64"
    echo "[i] Cross-compiling wireguard-tools to amd64."
    echo "    Cross-toolchain required. Install if missing:"
    echo "      sudo apt-get install gcc-x86-64-linux-gnu binutils-x86-64-linux-gnu"
fi

BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/wireguard-tools_build # work directory
INSTALL_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/wireguard-tools_inst

echo "******** Creating work-folder (${BUILD_DIR})..."
rm -rf ${BUILD_DIR}
rm -rf ${INSTALL_DIR}
mkdir -pv ${BUILD_DIR}
mkdir -pv ${INSTALL_DIR}

echo "******** Cloning wireguard-tools sources..."
cd ${BUILD_DIR}
git clone https://git.zx2c4.com/wireguard-tools/
cd wireguard-tools

echo "******** Checkout wireguard-tools version (${WG_TOOLS_VER})..."
git checkout ${WG_TOOLS_VER}
cd src

echo "******** Compiling 'wireguard-tools' (arch: ${ARCH_TARGET})..."
make $MAKE_VARS

echo "******** Copying 'wireguard-tools' binaries..."
cp ${BUILD_DIR}/wireguard-tools/src/wg ${INSTALL_DIR}
cp ${BUILD_DIR}/wireguard-tools/src/wg-quick/linux.bash ${INSTALL_DIR}/wg-quick

echo "********************************"
echo "******** BUILD COMPLETE ********"
echo "********************************"