#!/bin/bash

# Clean IVPN daemon build artifacts for macOS.
#
# Usage:
#   ./clean.sh          # clean all arches (default)
#   ./clean.sh arm64    # clean arm64 only
#   ./clean.sh x86_64   # clean x86_64 only

SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

_ARCH="${1:-all}"

echo "=================================================="
echo "======= CLEAN IVPN macOS Build Artifacts ========="
echo "=================================================="
echo "ARCH : $_ARCH"
echo ""

clean_arch() {
    local _A="$1"
    echo "[*] Cleaning ${_A} artifacts ..."

    # Third-party dependency builds and installs
    local _DEPS_DIR="$SCRIPT_DIR/../_deps/$_A"
    if [ -d "$_DEPS_DIR" ]; then
        rm -rf "$_DEPS_DIR"
        echo "    removed: $_DEPS_DIR"
    fi

    # Daemon binary
    local _DAEMON_BIN_DIR="$SCRIPT_DIR/../../../bin/$_A"
    if [ -d "$_DAEMON_BIN_DIR" ]; then
        rm -rf "$_DAEMON_BIN_DIR"
        echo "    removed: $_DAEMON_BIN_DIR"
    fi
}

case "$_ARCH" in
    all)
        clean_arch "arm64"
        clean_arch "x86_64"
        ;;
    arm64|x86_64)
        clean_arch "$_ARCH"
        ;;
    *)
        echo "[!] Invalid architecture: $_ARCH"
        echo "[!] Supported: all, arm64, x86_64"
        exit 1
        ;;
esac

echo ""
echo "[+] Clean complete."
