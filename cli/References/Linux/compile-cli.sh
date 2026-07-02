#!/bin/bash

# Compile the IVPN CLI binary.
#
# Usage:
#   ./compile-cli.sh [-v <version>] [-debug]
#
# Environment variables:
#   ARCH_TARGET   Target architecture: amd64 (default on x86_64 host) or arm64.
#                 Output: _out_bin/<arch>/ivpn
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
OUT_FILE="$OUT_DIR/ivpn"
OUT_BASH_COMPLETION_SCRIPT=$OUT_DIR/ivpn.bash-completion

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

echo "======================================================"
echo "============== Compiling IVPN CLI ===================="
echo "======================================================"
echo "Version: $VERSION"
echo "Date   : $DATE"
echo "Commit : $COMMIT"
echo "Arch   : $ARCH_TARGET"

cd $SCRIPT_DIR/../../

echo "* updating dependencies..."
go get -v

if [[ "$@" == *"-debug"* ]]
then
    echo "Compiling in DEBUG mode"
    GOARCH=$ARCH_TARGET CGO_ENABLED=0 go build -tags debug -o "$OUT_FILE" -trimpath -ldflags "-X github.com/ivpn/desktop-app/daemon/version._version=$VERSION -X github.com/ivpn/desktop-app/daemon/version._commit=$COMMIT -X github.com/ivpn/desktop-app/daemon/version._time=$DATE"
else
    GOARCH=$ARCH_TARGET CGO_ENABLED=0 go build -o "$OUT_FILE" -trimpath -ldflags "-s -w -X github.com/ivpn/desktop-app/daemon/version._version=$VERSION -X github.com/ivpn/desktop-app/daemon/version._commit=$COMMIT -X github.com/ivpn/desktop-app/daemon/version._time=$DATE"
fi

# generate bash-completion script
$SCRIPT_DIR/bash-completion-generator-ivpn-cli.sh "$OUT_FILE" > "$OUT_BASH_COMPLETION_SCRIPT"
bash -n "$OUT_BASH_COMPLETION_SCRIPT" # check bash-completion script syntax


echo "Compiled CLI binary   : '$OUT_FILE'"
echo "Bash-completion script: '$OUT_BASH_COMPLETION_SCRIPT'"

set +e
