#!/bin/sh

# Build obfs4proxy from source.
#
# Usage:
#   ./build-obfs4proxy.sh
#
# Environment variables:
#   ARCH_TARGET   Target architecture: amd64 (default on x86_64 host) or arm64.
#                 Output: ../_deps/<arch>/obfs4proxy_inst/

OBFS4_VER=obfs4proxy-0.0.14

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

BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/obfs4proxy_build # work directory
INSTALL_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/obfs4proxy_inst

echo "******** Creating work-folder (${BUILD_DIR})..."
rm -rf ${BUILD_DIR}
rm -rf ${INSTALL_DIR}
mkdir -pv ${BUILD_DIR}
mkdir -pv ${INSTALL_DIR}

echo "******** Cloning obfs4proxy sources..."
cd ${BUILD_DIR}
git clone https://github.com/Yawning/obfs4.git
cd obfs4

echo "******** Checkout obfs4proxy version (${OBFS4_VER})..."
git checkout ${OBFS4_VER}

echo "******** Compiling 'obfs4proxy' (arch: ${ARCH_TARGET})..."
GOARCH=$ARCH_TARGET go build -o ${INSTALL_DIR}/obfs4proxy -trimpath -ldflags "-s -w" ./obfs4proxy

echo "********************************"
echo "******** BUILD COMPLETE ********"
echo "********************************"
