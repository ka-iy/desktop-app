#!/bin/sh

# ##############################################################################
# Define here WireGuard-Go version
# ##############################################################################
WG_GO_VER=0.0.20250522      # https://git.zx2c4.com/wireguard-go/
WG_TOOLS_VER=v1.0.20260223  # https://git.zx2c4.com/wireguard-tools/

# Exit immediately if a command exits with a non-zero status.
set -e

cd "$(dirname "$0")"
BASE_DIR="$(pwd)" #set base folder of script location

# ====== Architecture setup ======
_HOST_ARCH="$(uname -m)"
ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
  arm64)
    _ARCH_FLAG="-arch arm64"
    _GOARCH="arm64"
    _OPENSSL_TARGET="darwin64-arm64-cc"
    _AUTOCONF_HOST="aarch64-apple-darwin"
    ;;
  x86_64)
    _ARCH_FLAG="-arch x86_64"
    _GOARCH="amd64"
    _OPENSSL_TARGET="darwin64-x86_64-cc"
    _AUTOCONF_HOST="x86_64-apple-darwin"
    ;;
  *)
    echo "ERROR: Unsupported ARCH_TARGET='$ARCH_TARGET'. Use 'arm64' or 'x86_64'."
    exit 1
    ;;
esac
_DEPLOY_MIN="12.0"
_SDK="$(xcrun --sdk macosx --show-sdk-path)"
_CC="$(xcrun -f clang) ${_ARCH_FLAG} -isysroot ${_SDK}"
_CXX="$(xcrun -f clang++) ${_ARCH_FLAG} -isysroot ${_SDK}"
echo "    ARCH_TARGET: ${ARCH_TARGET}"
# ====== End architecture setup ======

BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/wg_build # work directory
INSTALL_DIR=${BUILD_DIR}/../wg_inst

# Function to set up temporary Go environment
# It downloads the specified Go version and sets up the environment variables
# Arguments:
#   $1: Go version to download
setup_go_env() {
    local GO_VERSION=$1
    local TEMP_GOROOT="${BUILD_DIR}/go-${GO_VERSION}"
    local TEMP_GOPATH="${BUILD_DIR}/gopath"
    
    # Get system architecture
    local ARCH="$(uname -m)"
    if [ "${ARCH}" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "${ARCH}" != "arm64" ]; then
        echo "ERROR: Unsupported architecture: ${ARCH}"
        exit 1
    fi
    
    # Create GOPATH directory if it doesn't exist
    mkdir -p "${TEMP_GOPATH}"
    
    # Check if Go is already installed in the expected location
    local NEED_DOWNLOAD=true
    if [ -d "${TEMP_GOROOT}" ] && [ -f "${TEMP_GOROOT}/bin/go" ]; then
        NEED_DOWNLOAD=false
    fi
    
    if [ "$NEED_DOWNLOAD" = true ]; then
        echo "Downloading Go ${GO_VERSION} for architecture ${ARCH}..."
        mkdir -p "${TEMP_GOROOT}"
        curl -sSL "https://go.dev/dl/go${GO_VERSION}.darwin-${ARCH}.tar.gz" | tar -xz -C "${TEMP_GOROOT}" --strip-components=1
    fi

    # Use the temporary Go installation
    export PATH="${TEMP_GOROOT}/bin:${PATH}"
    export GOROOT="${TEMP_GOROOT}"
    export GOPATH="${TEMP_GOPATH}"
    
    # Verify Go installation
    echo "Verifying Go installation..."
    go version
    if [ $? -ne 0 ]; then
        echo "Failed to set up Go environment"
        exit 1
    fi
}

echo "******** Creating work-folder (${BUILD_DIR})..."

if [ -d "${BUILD_DIR}" ]; then
  # Ensure the build directory is writable, as Go makes files in the module cache read-only
  chmod -R +w "${BUILD_DIR}"
fi
rm -rf ${BUILD_DIR}
rm -rf ${INSTALL_DIR}
mkdir -pv ${BUILD_DIR}
mkdir -pv ${INSTALL_DIR}

#echo "******** Setting up Go environment version ${GO_VERSION}..."
# Use the temporary Go v1.22.12 environment because 'wireguard-go' fails when using Go >= 1.23
#setup_go_env "1.22.12" # TODO: Remove this when wireguard-go supports latest Go versions

echo "******** Cloning WireGuard-go sources (version ${WG_GO_VER})..."
cd ${BUILD_DIR}
git clone --branch "${WG_GO_VER}" --depth 1 https://git.zx2c4.com/wireguard-go/
cd wireguard-go

echo "******** Compiling 'wireguard-go'..."
CC="${_CC}" \
GOOS=darwin GOARCH=${_GOARCH} CGO_ENABLED=1 \
CGO_CFLAGS="-mmacosx-version-min=${_DEPLOY_MIN} ${_ARCH_FLAG}" \
CGO_LDFLAGS="-mmacosx-version-min=${_DEPLOY_MIN} ${_ARCH_FLAG}" \
make

echo "******** Cloning wireguard-tools sources (version ${WG_TOOLS_VER})..."
cd ${BUILD_DIR}
git clone --branch "${WG_TOOLS_VER}" --depth 1 https://git.zx2c4.com/wireguard-tools/
cd wireguard-tools/src

echo "******** Compiling 'wireguard-tools'..."
CC="${_CC}" \
CFLAGS="-mmacosx-version-min=${_DEPLOY_MIN}" \
LDFLAGS="-mmacosx-version-min=${_DEPLOY_MIN}" \
make

echo "********************************"
echo "******** BUILD COMPLETE ********"
echo "********************************"

echo "******** Copying compiled binaries to '$BUILD_DIR"
cd ${BUILD_DIR}
cp ./wireguard-go/wireguard-go $INSTALL_DIR
cp ./wireguard-tools/src/wg $INSTALL_DIR
