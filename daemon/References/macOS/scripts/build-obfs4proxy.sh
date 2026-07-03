#!/bin/sh

OBFS4_VER=obfs4proxy-0.0.14

# Exit immediately if a command exits with a non-zero status.
set -e

cd "$(dirname "$0")"
BASE_DIR="$(pwd)" #set base folder of script location

# ====== Architecture setup ======
_HOST_ARCH="$(uname -m)"
ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
  arm64)  _GOARCH="arm64" ;;
  x86_64) _GOARCH="amd64" ;;
  *)
    echo "ERROR: Unsupported ARCH_TARGET='$ARCH_TARGET'. Use 'arm64' or 'x86_64'."
    exit 1
    ;;
esac
echo "    ARCH_TARGET: ${ARCH_TARGET}"
# ====== End architecture setup ======

BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/obfs4proxy_build # work directory
INSTALL_DIR=${BUILD_DIR}/../obfs4proxy_inst

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

echo "******** Compiling 'obfs4proxy'..."
GOOS=darwin GOARCH=${_GOARCH} go build -o ${INSTALL_DIR}/obfs4proxy -trimpath -ldflags "-s -w" ./obfs4proxy

echo "********************************"
echo "******** BUILD COMPLETE ********"
echo "********************************"
