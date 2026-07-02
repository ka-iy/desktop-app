#!/bin/bash

# Clean IVPN daemon build artifacts for a given architecture.
#
# Usage:
#   ./clean-all.sh          # clean all arches (default)
#   ./clean-all.sh amd64    # clean amd64 only
#   ./clean-all.sh arm64    # clean arm64 only

SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Determine target architecture. Default: all.
_ARCH="${1:-all}"

echo "=================================================="
echo "============ CLEAN IVPN Service Artifacts ========"
echo "=================================================="
echo "ARCH : $_ARCH"
echo ""

clean_arch() {
    local _A="$1"
    echo "[*] Cleaning ${_A} artifacts ..."

    # Daemon service binary
    local _OUT_DIR="$SCRIPT_DIR/_out_bin/$_A"
    if [ -d "$_OUT_DIR" ]; then
        rm -rf "$_OUT_DIR"
        echo "    removed: $_OUT_DIR"
    fi

    # All dependency build and install dirs for this arch
    local _DEPS_DIR="$SCRIPT_DIR/../_deps/$_A"
    if [ -d "$_DEPS_DIR" ]; then
        rm -rf "$_DEPS_DIR"
        echo "    removed: $_DEPS_DIR"
    fi
}

case "$_ARCH" in
    all)
        clean_arch "amd64"
        clean_arch "arm64"
        ;;
    amd64|arm64)
        clean_arch "$_ARCH"
        ;;
    *)
        echo "[!] Invalid architecture: $_ARCH"
        echo "[!] Supported: all, amd64, arm64"
        exit 1
        ;;
esac

echo "[*] Done."
