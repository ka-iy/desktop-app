#!/bin/sh

# ##############################################################################
# Define here OpenSSL and OpenVPN versions
# ##############################################################################
OPEN_SSL_VER=3.2.0
OPEN_VPN_VER=v2.6.8

LZO_VER=2.10

# This has to be installed
echo "******** Installing xcode command lines tools..."
xcode-select --install
# Exit immediately if a command exits with a non-zero status.
set -e

cd "$(dirname "$0")"
BASE_DIR="$(pwd)" #set base folder of script location

# Determine number of CPU cores for parallel compilation
CPU_CORES=$(sysctl -n hw.logicalcpu)

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

BUILD_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/openvpn_build # work directory
INSTALL_DIR=${BASE_DIR}/../_deps/${ARCH_TARGET}/openvpn_inst

echo "******** Creating work-folder (${BUILD_DIR})..."
rm -rf ${BUILD_DIR}
rm -rf ${INSTALL_DIR}

mkdir -pv ${BUILD_DIR}
mkdir -pv ${INSTALL_DIR}
mkdir -pv ${INSTALL_DIR}/include
mkdir -pv ${INSTALL_DIR}/lib

echo "************************************************"
echo "******** Downloading OpenSSL sources..."
echo "************************************************"
cd ${BUILD_DIR}
curl -L https://www.openssl.org/source/openssl-${OPEN_SSL_VER}.tar.gz | tar zx

# ##############################################################################
# Compilation OpenSSl info:
# https://wiki.openssl.org/index.php/Compilation_and_Installation#OS_X
#
# If you want to use OS-default SHARED openssl libraries - skip steps of compilation OpenSSL
# ##############################################################################
echo "************************************************"
echo "******** Configuring OpenSSL..."
echo "************************************************"
cd ${BUILD_DIR}/openssl-${OPEN_SSL_VER}

CC="${_CC}" \
./Configure ${_OPENSSL_TARGET} shared \
    enable-ec_nistp_64_gcc_128 no-ssl2 no-ssl3 no-comp \
    --openssldir=/usr/local/ssl/macos-${ARCH_TARGET} \
    -mmacosx-version-min=${_DEPLOY_MIN}

echo "************************************************"
echo "******** Compiling OpenSSL..."
echo "************************************************"
make -j$CPU_CORES

echo "************************************************"
echo "******** Copying OpenSSL include folder and static libraries..."

# if you want to use OS-default SHARED openssl libraries - not necessary to compile it.
# Just copy required headers of OpenSSL (include folder)
cp -r ${BUILD_DIR}/openssl-${OPEN_SSL_VER}/include/openssl ${INSTALL_DIR}/include/
# if you want to use OS-default SHARED openssl libraries - skip copying this static libraries
cp ${BUILD_DIR}/openssl-${OPEN_SSL_VER}/libcrypto.a ${INSTALL_DIR}/lib/
cp ${BUILD_DIR}/openssl-${OPEN_SSL_VER}/libssl.a ${INSTALL_DIR}/lib/

echo "************************************************"
echo "******** Downloading LZO sources..."
echo "************************************************"
cd ${BUILD_DIR}
curl https://www.oberhumer.com/opensource/lzo/download/lzo-${LZO_VER}.tar.gz | tar zx
cd lzo-${LZO_VER}

echo "************************************************"
echo "******** Compiling LZO..."
echo "************************************************"
CC="${_CC}" CFLAGS="-mmacosx-version-min=${_DEPLOY_MIN}" \
./configure --prefix="${INSTALL_DIR}" --host="${_AUTOCONF_HOST}" \
&& make -j$CPU_CORES && make install

echo "************************************************"
echo "******** Cloning OpenVPN sources (version ${OPEN_VPN_VER})..."
echo "************************************************"
cd ${BUILD_DIR}
git clone --branch "${OPEN_VPN_VER}" --depth 1 https://github.com/OpenVPN/openvpn.git
cd openvpn

echo "************************************************"
echo "******** OpenVPN: Updating generated configuration files..."
echo "************************************************"
autoreconf -ivf

echo "************************************************"
echo "******** Configuring OpenVPN..."
echo "************************************************"
CC="${_CC}" \
OPENSSL_LIBS="-L${INSTALL_DIR}/lib -lssl -lcrypto" \
OPENSSL_CFLAGS="-I${INSTALL_DIR}/include" \
CFLAGS="-mmacosx-version-min=${_DEPLOY_MIN} -I${INSTALL_DIR}/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib" \
    ./configure --host="${_AUTOCONF_HOST}" \
    --disable-debug --disable-server --enable-password-save \
    --disable-lz4
    # disabling lz4 compression algorithm (there is compilation error on macOS M1 when LZ4 enabled)

echo "************************************************"
echo "******** Compiling OpenVPN..."
echo "************************************************"
make -j$CPU_CORES

echo "********************************"
echo "******** BUILD COMPLETE ********"
echo "********************************"
mkdir -p ${INSTALL_DIR}/bin
cp ${BUILD_DIR}/openvpn/src/openvpn/openvpn ${INSTALL_DIR}/bin

set +e
${INSTALL_DIR}/bin/openvpn --version

echo "********************************"
echo "******** Please check the dynamic libraries OpenVPN uses ********"
echo "********************************"
otool -L ${INSTALL_DIR}/bin/openvpn

echo "********************************"
echo " DO NOT FORGET TO RECOMPILE 'IVPN Agent' project!"
echo "********************************"
