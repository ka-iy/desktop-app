#!/bin/sh

# Build kem-helper (liboqs + kem-helper binary) from source.
#
# Usage:
#   ./build-kem-helper.sh
#
# Environment variables:
#   ARCH_TARGET   Target architecture: amd64 (default on x86_64 host) or arm64.
#   CROSS_ARCH    Cross-compiler selector (auto-derived from ARCH_TARGET).
#                 Output: ../_deps/<arch>/kem-helper/kem-helper-bin/

# Exit immediately if a command exits with a non-zero status.
set -e

cd "$(dirname "$0")"
BASE_DIR="$(pwd)" #set base folder of script location

# --- Target architecture ---
_HOST_ARCH="$(uname -m)"
[ "$_HOST_ARCH" = "aarch64" ] && _HOST_ARCH="arm64"
[ "$_HOST_ARCH" = "x86_64"  ] && _HOST_ARCH="amd64"
export ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
    amd64|arm64) ;;
    *) echo "[!] ERROR: unsupported ARCH_TARGET='$ARCH_TARGET'. Must be 'amd64' or 'arm64'."; exit 1 ;;
esac
export CROSS_ARCH="${CROSS_ARCH:-}"
[ -z "$CROSS_ARCH" ] && [ "$ARCH_TARGET" != "$_HOST_ARCH" ] && export CROSS_ARCH="$ARCH_TARGET"

# --- Cross-compilation flags ---
if [ "$CROSS_ARCH" = "arm64" ]; then
    echo "[i] Cross-compiling kem-helper to arm64."
    echo "    Required cross-toolchain and cmake. Install if missing:"
    echo "      sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu cmake ninja-build"
elif [ "$CROSS_ARCH" = "amd64" ]; then
    echo "[i] Cross-compiling kem-helper to amd64."
    echo "    Required cross-toolchain and cmake. Install if missing:"
    echo "      sudo apt-get install gcc-x86-64-linux-gnu binutils-x86-64-linux-gnu cmake ninja-build"
else
    echo "[i] Native build of kem-helper for ${ARCH_TARGET}."
fi

BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/kem-helper

echo "******** Creating work-folder (${BUILD_DIR})..."
rm -rf ${BUILD_DIR}
mkdir -pv ${BUILD_DIR}

echo "******** Compiling (kem-helper, arch: ${ARCH_TARGET})..."
./../../common/kem-helper/build.sh -d $BUILD_DIR

echo "********************************"
echo "******** BUILD COMPLETE ********"
echo "********************************"