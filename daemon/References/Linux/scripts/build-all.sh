#!/bin/bash

# Build all IVPN daemon dependencies and the daemon itself.
#
# Usage:
#   ./build-all.sh [-v <version>] [-c]
#
#   -v <version>   Package version string passed to the daemon build.
#   -C             Clean artifacts for the target arch before building.
#
# Environment variables:
#   ARCH_TARGET    Target architecture: amd64 (default on x86_64 host) or arm64.
#   CROSS_ARCH     Cross-compiler selector. Auto-derived from ARCH_TARGET when
#                  the target differs from the host. Can also be set explicitly.
#   IVPN_BUILD_SKIP_GLIBC_VER_CHECK=1
#                  Skip the host GLIBC version check (useful on Ubuntu 22+).
#
# Examples:
#   ./build-all.sh -v 3.10.9              # native build
#   ARCH_TARGET=arm64 ./build-all.sh      # ARM64 cross-compile
#   ARCH_TARGET=arm64 ./build-all.sh -C   # clean then cross-compile
#   ./clean-all.sh                        # clean all arch artifacts

cd "$(dirname "$0")"

SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
OUT_DIR="$SCRIPT_DIR/_out_bin"

GLIBC_VER_MAX_REQUIRED="2.31" # GLIBC v2.31 is the default version in Ubuntu 20.04 LTS (Focal Fossa)

set -e

# make output dir if not exists
mkdir -p $OUT_DIR

# --- Target architecture ---
_HOST_ARCH="$(uname -m)"
[ "$_HOST_ARCH" = "aarch64" ] && _HOST_ARCH="arm64"
[ "$_HOST_ARCH" = "x86_64"  ] && _HOST_ARCH="amd64"
export ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
    amd64|arm64) ;;
    *) echo "[!] ERROR: unsupported ARCH_TARGET='$ARCH_TARGET'. Must be 'amd64' or 'arm64'."; exit 1 ;;
esac
export CROSS_ARCH=""
[ "$ARCH_TARGET" != "$_HOST_ARCH" ] && export CROSS_ARCH="$ARCH_TARGET"

# -C flag: clean artifacts for the target arch before building
for arg in "$@"; do
    if [ "$arg" = "-C" ]; then
        echo "[*] Cleaning artifacts for '${ARCH_TARGET}' before build ..."
        "$SCRIPT_DIR/clean-all.sh" "$ARCH_TARGET"
        break
    fi
done
# Check required GLIBC version. 
# Compiling with the new GLIBC version will not allow the program to start on systems with the old GLIBC (error example: "version 'GLIBC_2.34' not found"). 
# Useful links:
#   https://utcc.utoronto.ca/~cks/space/blog/programming/GoAndGlibcVersioning
# Useful commands:
#   ldd -r -v <binary_file> # check shared libraries dependencies
#
if [ -z "${CROSS_ARCH:-}" ]; then   # skip for cross-compile runs
  GLIBC_VER=$(ldd --version | grep "ldd (" | awk '{print $(NF)}')
  if [[ "${GLIBC_VER}" > "${GLIBC_VER_MAX_REQUIRED}" ]]; then
    if [ -n "${IVPN_BUILD_SKIP_GLIBC_VER_CHECK:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
      echo "[!] GLIBC version '${GLIBC_VER}' > '${GLIBC_VER_MAX_REQUIRED}' (check skipped by env var)"
    else
      echo "[!] ERROR: GLIBC version '${GLIBC_VER}' is newer than required '${GLIBC_VER_MAX_REQUIRED}'"
      echo "[!]     Binaries compiled on this host may not run on systems with older GLIBC."
      echo "[!]     To override: set IVPN_BUILD_SKIP_GLIBC_VER_CHECK=1"
      exit 1
    fi
  fi
fi

echo ""

# check if we need to compile obfs4proxy
if [[ ! -f "../_deps/${ARCH_TARGET}/obfs4proxy_inst/obfs4proxy" ]]
then
  echo "======================================================"
  echo "========== Compiling obfs4proxy ======================"
  echo "======================================================"
  cd $SCRIPT_DIR
  ./build-obfs4proxy.sh
else
  echo " - 'obfs4proxy' already compiled. Skipping build."
fi

# check if we need to compile wireguard-tools
if [[ ! -f "../_deps/${ARCH_TARGET}/wireguard-tools_inst/wg-quick" ]] || [[ ! -f "../_deps/${ARCH_TARGET}/wireguard-tools_inst/wg" ]]
then
  echo "======================================================"
  echo "========== Compiling wireguard-tools ================="
  echo "======================================================"
  cd $SCRIPT_DIR
  ./build-wireguard-tools.sh
else
  echo " - 'wireguard-tools' already compiled. Skipping build."
fi

# check if we need to compile dnscrypt-proxy
if [[ ! -f "../_deps/${ARCH_TARGET}/dnscryptproxy_inst/dnscrypt-proxy" ]] 
then
  echo "======================================================"
  echo "========== Compiling dnscrypt-proxy =================="
  echo "======================================================"
  cd $SCRIPT_DIR
  ./build-dnscrypt-proxy.sh
else
  echo " - 'dnscrypt-proxy' already compiled. Skipping build."
fi

# check if we need to compile v2ray
if [[ ! -f "../_deps/${ARCH_TARGET}/v2ray_inst/v2ray" ]]
then
  echo "======================================================"
  echo "========== Compiling v2ray ==========================="
  echo "======================================================"
  cd $SCRIPT_DIR

  if [ ! -z "$GITHUB_ACTIONS" ]; 
  then
    echo "! GITHUB_ACTIONS detected ! It is just a build test."
    echo "! Skipped compilation of V2Ray !"
  else
    ./build-v2ray.sh
  fi

else
  echo " - 'v2ray' already compiled. Skipping build."
fi

# check if we need to compile kem-helper
if [[ ! -f "../_deps/${ARCH_TARGET}/kem-helper/kem-helper-bin/kem-helper" ]]
then
  echo "======================================================"
  echo "========== Compiling kem-helper ======================"
  echo "======================================================"
  cd $SCRIPT_DIR

  if [ ! -z "$GITHUB_ACTIONS" ]; 
  then
    echo "! GITHUB_ACTIONS detected ! It is just a build test."
    echo "! Skipped compilation of kem-helper !"
  else
    ./build-kem-helper.sh
  fi

else
  echo " - 'kem-helper' already compiled. Skipping build."
fi

echo "======================================================"
echo "============ Compiling IVPN service =================="
echo "======================================================"
./build-daemon.sh $@

echo "======================================================"
echo "[+] Checking compiled binaries (arch + GLIBC compatibility) ..."
BINARIES=(
    "$SCRIPT_DIR/../_deps/${ARCH_TARGET}/wireguard-tools_inst/wg"
    "$SCRIPT_DIR/../_deps/${ARCH_TARGET}/obfs4proxy_inst/obfs4proxy" 
    "$SCRIPT_DIR/../_deps/${ARCH_TARGET}/dnscryptproxy_inst/dnscrypt-proxy"
    "$SCRIPT_DIR/../_deps/${ARCH_TARGET}/v2ray_inst/v2ray"
    "$SCRIPT_DIR/../_deps/${ARCH_TARGET}/kem-helper/kem-helper-bin/kem-helper"
    "$SCRIPT_DIR/_out_bin/${ARCH_TARGET}/ivpn-service"
)
EXPECTED_MACHINE=""
[ "$ARCH_TARGET" = "arm64" ] && EXPECTED_MACHINE="AArch64"
[ "$ARCH_TARGET" = "amd64" ] && EXPECTED_MACHINE="X86-64"
ISSUES=0
for bin in "${BINARIES[@]}"; do
    [[ ! -f "$bin" ]] && { echo "    [SKIP] $(basename "$bin") - not found"; continue; }

    # Check architecture (readelf works cross-arch, unlike file/ldd)
    BIN_MACHINE=$(readelf -h "$bin" 2>/dev/null | awk '/Machine:/{print $NF}')
    if [ -n "$EXPECTED_MACHINE" ] && [ "$BIN_MACHINE" != "$EXPECTED_MACHINE" ]; then
        echo "    [FAIL] $(basename "$bin") - wrong arch: $BIN_MACHINE (expected $EXPECTED_MACHINE)"
        ISSUES=$((ISSUES + 1))
        continue
    fi

    # Check GLIBC compatibility (readelf -d avoids executing the binary, safe for cross-arch)
    if ! readelf -d "$bin" 2>/dev/null | grep -q "NEEDED"; then
        echo "    [OK] $(basename "$bin") - static, arch: $BIN_MACHINE"
    else
        MAX_GLIBC=$(objdump -T "$bin" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | sort -V | tail -1 | cut -d_ -f2)
        if [[ -n "$MAX_GLIBC" && "$MAX_GLIBC" > "$GLIBC_VER_MAX_REQUIRED" ]]; then
            echo "    [FAIL] $(basename "$bin") - requires GLIBC_$MAX_GLIBC > $GLIBC_VER_MAX_REQUIRED (arch: $BIN_MACHINE)"
            ISSUES=$((ISSUES + 1))
        else
            echo "    [OK] $(basename "$bin") - arch: $BIN_MACHINE, GLIBC_${MAX_GLIBC:-none}"
        fi
    fi
done
if [[ $ISSUES -eq 0 ]]; then
    echo "✓ All binaries compatible with GLIBC $GLIBC_VER_MAX_REQUIRED"
else
    echo    "⚠ $ISSUES binaries need attention"
    echo    "    Some binaries require newer GLIBC than $GLIBC_VER_MAX_REQUIRED"
    echo    "    These binaries may not work on older Linux distributions."
    if [ -n "${IVPN_BUILD_SKIP_GLIBC_VER_CHECK:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "[!] GLIBC compatibility issues detected (check skipped by env var)"
    else
        echo "[!] ERROR: GLIBC compatibility check failed."
        echo "[!]     To override: set IVPN_BUILD_SKIP_GLIBC_VER_CHECK=1"
        exit 1
    fi
fi
echo "======================================================"

set +e
