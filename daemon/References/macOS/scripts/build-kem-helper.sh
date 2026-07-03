#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

cd "$(dirname "$0")"
BASE_DIR="$(pwd)" #set base folder of script location

# ====== Architecture setup ======
_HOST_ARCH="$(uname -m)"
ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
  arm64)  _ARCH_FLAG="-arch arm64" ;;
  x86_64) _ARCH_FLAG="-arch x86_64" ;;
  *)
    echo "ERROR: Unsupported ARCH_TARGET='$ARCH_TARGET'. Use 'arm64' or 'x86_64'."
    exit 1
    ;;
esac
_DEPLOY_MIN="12.0"
_SDK="$(xcrun --sdk macosx --show-sdk-path)"
_CC="$(xcrun -f clang) ${_ARCH_FLAG} -isysroot ${_SDK}"
echo "    ARCH_TARGET: ${ARCH_TARGET}"
# ====== End architecture setup ======

BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/kem-helper # work directory

echo "******** Creating work-folder (${BUILD_DIR})..."
rm -rf ${BUILD_DIR}
mkdir -pv ${BUILD_DIR}

echo "******** Compiling (kem-helper)..."
export CC="${_CC}"
export CFLAGS="${_ARCH_FLAG} -isysroot ${_SDK}"
export MACOS_CMAKE_FLAGS="-DCMAKE_OSX_ARCHITECTURES=${ARCH_TARGET} -DCMAKE_OSX_DEPLOYMENT_TARGET=${_DEPLOY_MIN}"

# When cross-compiling (ARCH_TARGET differs from the host), liboqs reads
# CMAKE_SYSTEM_PROCESSOR (set from the host) and injects host-specific flags
# (e.g. -march=armv8-a+crypto on Apple Silicon) into every translation unit,
# breaking the target-arch build. A CMake toolchain file is loaded before
# project()/CMakeLists.txt and is the only reliable way to override
# CMAKE_SYSTEM_PROCESSOR before liboqs's architecture detection runs.
if [ "${ARCH_TARGET}" != "$(uname -m)" ]; then
    _TOOLCHAIN_FILE="${BUILD_DIR}/cross_toolchain.cmake"
    printf 'set(CMAKE_SYSTEM_NAME "Darwin")\nset(CMAKE_SYSTEM_PROCESSOR "%s")\n' \
        "${ARCH_TARGET}" > "${_TOOLCHAIN_FILE}"
    export MACOS_CMAKE_FLAGS="${MACOS_CMAKE_FLAGS} -DCMAKE_TOOLCHAIN_FILE=${_TOOLCHAIN_FILE}"
fi
./../../common/kem-helper/build.sh -d $BUILD_DIR

echo "********************************"
echo "******** BUILD COMPLETE ********"
echo "********************************"