#!/bin/bash

# Build the Electron UI app via electron-builder.
# Output: dist/linux-<arch>-unpacked/
#
# Usage:
#   ./compile-ui.sh
#
# Environment variables:
#   ARCH_TARGET   Target architecture: amd64 (default on x86_64 host) or arm64.
#                 Calls npm run electron:build:linux:x64 or :arm64 accordingly.

cd "$(dirname "$0")"
cd ../..

# --- Target architecture ---
_HOST_ARCH="$(uname -m)"
[ "$_HOST_ARCH" = "aarch64" ] && _HOST_ARCH="arm64"
[ "$_HOST_ARCH" = "x86_64"  ] && _HOST_ARCH="amd64"
ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
    amd64|arm64) ;;
    *) echo "[!] ERROR: unsupported ARCH_TARGET='$ARCH_TARGET'. Must be 'amd64' or 'arm64'."; exit 1 ;;
esac

echo "[+] Building (arch: ${ARCH_TARGET})..."
if [ "$ARCH_TARGET" = "arm64" ]; then
    npm run electron:build:linux:arm64
else
    npm run electron:build:linux:x64
fi
