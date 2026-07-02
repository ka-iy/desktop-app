#!/bin/sh

# Build v2ray from source.
#
# Usage:
#   ./build-v2ray.sh
#
# Environment variables:
#   ARCH_TARGET   Target architecture: amd64 (default on x86_64 host) or arm64.
#                 Output: ../_deps/<arch>/v2ray_inst/

V2RAY_VER=v5.12.1

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

BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/v2ray_build # work directory
INSTALL_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/v2ray_inst

echo "******** Creating work-folder (${BUILD_DIR})..."
rm -rf ${BUILD_DIR}
rm -rf ${INSTALL_DIR}
mkdir -pv ${BUILD_DIR}
mkdir -pv ${INSTALL_DIR}

echo "******** Cloning V2Ray sources..."
cd ${BUILD_DIR}
git clone  --depth 1 --branch ${V2RAY_VER} https://github.com/v2fly/v2ray-core.git
cd v2ray-core/main

echo "******** Compiling 'V2Ray' (arch: ${ARCH_TARGET})..."
GOARCH=$ARCH_TARGET go build -o ${INSTALL_DIR}/v2ray -trimpath -ldflags "-s -w"

echo "********************************"
echo "******** BUILD COMPLETE ********"
echo "********************************"