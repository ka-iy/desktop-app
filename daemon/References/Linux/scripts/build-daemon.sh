#!/bin/bash

# Build the IVPN daemon (ivpn-service) binary.
#
# Usage:
#   ./build-daemon.sh [-v <version>]
#
# Environment variables:
#   ARCH_TARGET   Target architecture: amd64 (default on x86_64 host) or arm64.
#                 Output: scripts/_out_bin/<arch>/ivpn-service
cd "$(dirname "$0")"

SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# --- Target architecture ---
_HOST_ARCH="$(uname -m)"
[ "$_HOST_ARCH" = "aarch64" ] && _HOST_ARCH="arm64"
[ "$_HOST_ARCH" = "x86_64"  ] && _HOST_ARCH="amd64"
ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
    amd64|arm64) ;;
    *) echo "[!] ERROR: unsupported ARCH_TARGET='$ARCH_TARGET'. Must be 'amd64' or 'arm64'."; exit 1 ;;
esac

OUT_DIR="$SCRIPT_DIR/_out_bin/$ARCH_TARGET"
OUT_FILE="$OUT_DIR/ivpn-service"

set -e

# make output dir if not exists
mkdir -p $OUT_DIR

# version info variables
VERSION=""
DATE="$(date "+%Y-%m-%d")"
COMMIT="$(git rev-list -1 HEAD)"

# reading version info from arguments
while getopts ":v:" opt; do
  case $opt in
    v) VERSION="$OPTARG"
    ;;
  esac
done

# updating servers.json
cd $SCRIPT_DIR
./update-servers.sh

echo "!!!!!!!!!!!!!!!!!!!! INFO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "Version: $VERSION"
echo "Date   : $DATE"
echo "Commit : $COMMIT"
echo "Arch   : $ARCH_TARGET"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

# Build
cd $SCRIPT_DIR/../../../

BUILDTAG_DEBUG=""  # "debug"
BUILDTAG_NOWIFI="" # "nowifi"

if [[ "$@" == *"-debug"* ]]
then
  echo "[!] Compiling in DEBUG mode."
  BUILDTAG_DEBUG="debug"
fi
if [ ! -z "$IVPN_NO_WIFI" ]; then
  echo "[!] WIFI functionality DISABLED."
  BUILDTAG_NOWIFI="nowifi"
fi

GOARCH=$ARCH_TARGET CGO_ENABLED=0 go build -buildmode=pie -tags "${BUILDTAG_DEBUG} ${BUILDTAG_NOWIFI}" -o "$OUT_FILE" -trimpath -ldflags "-X github.com/ivpn/desktop-app/daemon/version._version=$VERSION -X github.com/ivpn/desktop-app/daemon/version._commit=$COMMIT -X github.com/ivpn/desktop-app/daemon/version._time=$DATE"

echo "Compiled binary: '$OUT_FILE'"

set +e
