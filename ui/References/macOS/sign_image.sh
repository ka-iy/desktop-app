#!/bin/bash

#save current dir
_BASE_DIR="$( pwd )"
_SCRIPT=`basename "$0"`
#enter the script folder
cd "$(dirname "$0")"
_SCRIPT_DIR="$( pwd )"

# check result of last executed command
function CheckLastResult
{
  if ! [ $? -eq 0 ]; then #check result of last command
    if [ -n "$1" ]; then
      echo $1
    else
      echo "FAILED"
    fi
    exit 1
  fi
}

# The Apple DevID certificate which will be used to sign binaries
_SIGN_CERT=""
# reading version info from arguments
while getopts ":c:" opt; do
  case $opt in
    c) _SIGN_CERT="$OPTARG"
    ;;
  esac
done

if [ -z "${_SIGN_CERT}" ]; then
  echo "ERROR: Apple DevID not defined"
  echo "Usage:"
  echo "    $0 -c <APPLE_DEVID_SERT> [-libivpn]"
  exit 1
fi

ARCH_TARGET="${ARCH_TARGET:-$(uname -m)}"
_IMAGE_DIR="_image/${ARCH_TARGET}"

if [ ! -d "${_IMAGE_DIR}/IVPN.app" ]; then
  echo "ERROR: folder not exists '${_IMAGE_DIR}/IVPN.app'!"
fi

echo "[i] Signing by cert: '${_SIGN_CERT}'"

# temporarily setting the IFS (internal field seperator) to the newline character.
# (required to process result pf 'find' command)
IFS=$'\n'; set -f

echo "[+] Signing obfsproxy libraries..."
for f in $(find "${_IMAGE_DIR}/IVPN.app/Contents/Resources/obfsproxy" -name '*.so');
do
  echo "    signing: [" $f "]";
  codesign --verbose=4 --force --sign "${_SIGN_CERT}" "$f"
  CheckLastResult "Signing failed"
done

#restore temporarily setting the IFS (internal field seperator)
unset IFS; set +f

ListCompiledLibs=()
if [[ "$@" == *"-libivpn"* ]]
then
  ListCompiledLibs=(
  "${_IMAGE_DIR}/IVPN.app/Contents/MacOS/libivpn.dylib"
  )
fi

ListCompiledBinaries=(
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/IVPN"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/IVPN Agent"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/cli/ivpn"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/kem/kem-helper"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/IVPN Installer.app/Contents/MacOS/IVPN Installer"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/IVPN Installer.app"
"${_IMAGE_DIR}/IVPN.app"
"${_IMAGE_DIR}/IVPN Uninstaller.app"
"${_IMAGE_DIR}/IVPN Uninstaller.app/Contents/MacOS/IVPN Uninstaller"
)

ListThirdPartyBinaries=(
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/IVPN Installer.app/Contents/Library/LaunchServices/net.ivpn.client.Helper"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/net.ivpn.LaunchAgent"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/openvpn"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/WireGuard/wg"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/WireGuard/wireguard-go"
"${_IMAGE_DIR}/IVPN.app/Contents/Resources/obfsproxy/obfs4proxy"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/v2ray/v2ray"
"${_IMAGE_DIR}/IVPN.app/Contents/MacOS/dnscrypt-proxy/dnscrypt-proxy"
)

echo "[+] Signing compiled libs..."
for f in "${ListCompiledLibs[@]}";
do
  echo "    signing: [" $f "]";
  codesign --verbose=4 --force --sign "${_SIGN_CERT}" "$f"
  CheckLastResult "Signing failed"
done

echo "[+] Signing third-party binaries..."
for f in "${ListThirdPartyBinaries[@]}";
do
  echo "    signing: [" $f "]";
  codesign --verbose=4 --force --sign "${_SIGN_CERT}" --options runtime "$f"
  CheckLastResult "Signing failed"
done

echo "[+] Signing compiled binaries..."
for f in "${ListCompiledBinaries[@]}";
do
  echo "    signing: [" $f "]";
  codesign --verbose=4 --force --sign "${_SIGN_CERT}" --options runtime "$f" --deep --entitlements build_HarderingEntitlements.plist
  CheckLastResult "Signing failed"
done
