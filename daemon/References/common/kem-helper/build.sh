#!/bin/bash

# #############################################################
# Dependencies: such packages required to be installed: 
# sudo apt install -y astyle cmake gcc ninja-build libssl-dev python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml valgrind
# #############################################################

_LIBOQS_VERSION="0.15.0"

_SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
_WORK_FOLDER=$_SCRIPT_DIR/_out_linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    _WORK_FOLDER=$_SCRIPT_DIR/_out_macos
fi

set -e

# Error handling function
handle_error() {
    echo "[!] An ERROR occurred in the script!"
    echo "    Please, note that script has dependencies"
    echo "    (https://github.com/open-quantum-safe/liboqs/tree/main#linuxmacos)"
    if [[ "$OSTYPE" == "darwin"* ]]; then        
        echo "      $ brew install cmake ninja openssl@1.1 wget doxygen graphviz astyle valgrind"
        echo "      $ pip3 install pytest pytest-xdist pyyaml"
    else    
        echo "      $ sudo apt install -y astyle git cmake gcc ninja-build libssl-dev python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml valgrind"
    fi
    echo "[!] Exiting (because of error)"
    exit 1
}
# Set the trap to catch errors
trap 'handle_error' ERR

# reading destination folder from arguments
while getopts ":d:" opt; do
  case $opt in
    d)  _WORK_FOLDER="$OPTARG"
        if [ ! -d "$_WORK_FOLDER" ]; then 
            echo "[!] ERROR: '$_WORK_FOLDER' does not exists!"
            exit 1
        fi
    ;;    
  esac
done

echo "[i] Using work folder: $_WORK_FOLDER"
_OUT_FOLDER=$_WORK_FOLDER/kem-helper-bin
_LIBOQS_FOLDER=$_WORK_FOLDER/liboqs
_LIBOQS_SOURCES_FOLDER=$_LIBOQS_FOLDER/liboqs
_LIBOQS_INSTALL_FOLDER=$_LIBOQS_FOLDER/INSTALL

# --- Cross-compilation flags (Linux) ---
CROSS_ARCH="${CROSS_ARCH:-}"
CMAKE_CROSS_FLAGS=""
GCC_CMD="gcc"
if [ "$CROSS_ARCH" = "arm64" ]; then
    CMAKE_CROSS_FLAGS="-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64"
    GCC_CMD="aarch64-linux-gnu-gcc"
elif [ "$CROSS_ARCH" = "amd64" ]; then
    CMAKE_CROSS_FLAGS="-DCMAKE_C_COMPILER=x86_64-linux-gnu-gcc -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64"
    GCC_CMD="x86_64-linux-gnu-gcc"
fi

# --- macOS: honor CC, CFLAGS, MACOS_CMAKE_FLAGS env vars for cross-compilation ---
_MACOS_CC=""
_MACOS_CFLAGS=""
_MACOS_CMAKE_COMPILER_FLAG=""
_MACOS_CMAKE_PLATFORM_FLAGS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    _MACOS_CC="${CC:-$(xcrun -f clang)}"
    _MACOS_CFLAGS="${CFLAGS:-}"
    # For CMake, pass only the bare compiler path; arch/sysroot are handled via MACOS_CMAKE_FLAGS
    # (_MACOS_CC may contain -arch/-isysroot flags which CMake does not accept in -DCMAKE_C_COMPILER)
    _MACOS_CMAKE_COMPILER_FLAG="-DCMAKE_C_COMPILER=$(xcrun -f clang)"
    _MACOS_CMAKE_PLATFORM_FLAGS="${MACOS_CMAKE_FLAGS:-}"
fi

if [ ! -d $_LIBOQS_FOLDER ]; then 
    echo "[*] Creating '$_LIBOQS_FOLDER' ..."
    mkdir -p $_LIBOQS_FOLDER
else
    echo "[*] Erasing '$_LIBOQS_FOLDER' ..."
    rm -fr $_LIBOQS_FOLDER/*
fi 
cd $_LIBOQS_FOLDER

echo "[*] Gettings liboqs v ${_LIBOQS_VERSION} sources ..."

git clone  --depth 1 --branch ${_LIBOQS_VERSION} https://github.com/open-quantum-safe/liboqs.git
cd liboqs

echo "[*] Configuring and compiling liboqs ..."
mkdir build && cd build

# If KEM_HELPER_ALL_ALGS not defined - do minimal build (only kyber and mceliece KEMs)
if [ -n "${KEM_HELPER_ALL_ALGS}" ]; then
    echo "[*] Configuring liboqs (FULL build) ..."
    cmake -GNinja .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$_LIBOQS_INSTALL_FOLDER \
        -DOQS_BUILD_ONLY_LIB=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DOQS_USE_OPENSSL=OFF \
        -DOQS_DIST_BUILD=ON \
        ${CMAKE_CROSS_FLAGS} \
        ${_MACOS_CMAKE_COMPILER_FLAG} \
        ${_MACOS_CMAKE_PLATFORM_FLAGS}
else
    echo "[*] Configuring liboqs (MINIMAL build) ..."
    cmake -GNinja .. \
        -DOQS_MINIMAL_BUILD="KEM_kyber_1024;KEM_classic_mceliece_348864;" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$_LIBOQS_INSTALL_FOLDER \
        -DOQS_BUILD_ONLY_LIB=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DOQS_USE_OPENSSL=OFF \
        -DOQS_DIST_BUILD=ON \
        ${CMAKE_CROSS_FLAGS} \
        ${_MACOS_CMAKE_COMPILER_FLAG} \
        ${_MACOS_CMAKE_PLATFORM_FLAGS}
fi

ninja
ninja install 

echo "[*] Compiling kem-helper ..."

if [ ! -d $_OUT_FOLDER ]; then 
    echo "[*] Creating '$_OUT_FOLDER' ..."
    mkdir -p $_OUT_FOLDER
else
    echo "[*] Erasing '$_OUT_FOLDER' ..."
    rm -fr $_OUT_FOLDER/*
fi 
echo "Sources '$_SCRIPT_DIR'" > $_OUT_FOLDER/readme.md

# Change the current working directory to the location of the source files
cd $_SCRIPT_DIR

if [[ "$OSTYPE" == "darwin"* ]]; then # macOS
    ${_MACOS_CC} main.c base64.c -o $_OUT_FOLDER/kem-helper \
        -Wall -O2 ${_MACOS_CFLAGS} \
        -I$_LIBOQS_INSTALL_FOLDER/include \
        -L$_LIBOQS_INSTALL_FOLDER/lib \
        -loqs -Wl,-stack_size,0x500000 #0x500000 is 5MB
else # linux
    _LIB_FOLDER=$_LIBOQS_INSTALL_FOLDER/lib
    if [ -d $_LIBOQS_INSTALL_FOLDER/lib64 ]; then 
        _LIB_FOLDER=$_LIBOQS_INSTALL_FOLDER/lib64        
    fi
    $GCC_CMD main.c base64.c -o $_OUT_FOLDER/kem-helper -pthread -Wall -O2 -I$_LIBOQS_INSTALL_FOLDER/include -L$_LIB_FOLDER -loqs -Wl,-z,stack-size=5242880 
fi

echo "[ ] SUCCESS"
echo "    kem-helper binary: '$_OUT_FOLDER/kem-helper'"