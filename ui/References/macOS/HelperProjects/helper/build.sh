#!/bin/bash

#save current dir
_BASE_DIR="$( pwd )"
_SCRIPT=`basename "$0"`
#enter the script folder
cd "$(dirname "$0")"

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

# The Apple DevID certificate which will be used to sign IVPN Agent (Daemon) binary
# The helper will check IVPN Agent signature with this value
_SIGN_CERT="" # E.g. "WXXXXXXXXN". Specific value can be passed by command-line argument: -c <APPLE_DEVID_SERT>
# version info variables
_VERSION=""

# reading version info from arguments
while getopts ":v:c:" opt; do
  case $opt in
    v) _VERSION="$OPTARG"
    ;;
    c) _SIGN_CERT="$OPTARG"
    ;;
  esac
done

if [ -z "${_VERSION}" ] || [ -z "${_SIGN_CERT}" ]; then
  echo "Usage:"
  echo "    $0 -v <version> -c <APPLE_DEVID_CERTIFICATE>"
  echo "    Example: $0 -v 0.0.1 -c WXXXXXXXXN"
  exit 1
fi

echo "[ ] *** Compiling IVPN helper ***"
echo "    Version:                 '${_VERSION}'"
echo "    Apple DevID certificate: '${_SIGN_CERT}'"

# ====== Architecture setup ======
_HOST_ARCH="$(uname -m)"
ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
  arm64)  _ARCH_FLAG="-arch arm64" ;;
  x86_64) _ARCH_FLAG="-arch x86_64" ;;
  *)
    echo "ERROR: Unsupported ARCH_TARGET='$ARCH_TARGET'. Use 'arm64' or 'x86_64'."
    exit 1
    ;;
esac
_DEPLOY_MIN="12.0"
_SDK="$(xcrun --sdk macosx --show-sdk-path)"
echo "    ARCH_TARGET: ${ARCH_TARGET}"
# ====== End architecture setup ======

# ======================== VARS =========================
_CFLAGS=""
_OUT_DIR="_out/${ARCH_TARGET}"
_OUT_BINARY="${_OUT_DIR}/net.ivpn.client.Helper"
_PLIST_LAUNCHD="IVPN Helper-Launchd.plist"

_PLIST_INFO_TEMPLATE="IVPN Helper-Info_template.plist"
_PLIST_INFO="IVPN Helper-Info.plist"

# ================ UPDATING PLIST FILES =================
echo "[+] Ubdating PLIST ..."
cp "${_PLIST_INFO_TEMPLATE}" "${_PLIST_INFO}"|| CheckLastResult

#plutil -replace SMAuthorizedClients -xml "<array> <string>identifier net.ivpn.client.installer and certificate leaf[subject.OU] = ${_SIGN_CERT}</string> </array>" "${_PLIST_INFO}" || CheckLastResult
plutil -replace SMAuthorizedClients -xml \
        "<array> \
          <string>identifier net.ivpn.client.installer and certificate leaf[subject.OU] = ${_SIGN_CERT}</string>\
          <string>identifier net.ivpn.client.uninstaller and certificate leaf[subject.OU] = ${_SIGN_CERT}</string>\
          <string>identifier net.ivpn.LaunchAgent and certificate leaf[subject.OU] = ${_SIGN_CERT}</string>\
        </array>" "${_PLIST_INFO}" || CheckLastResult

plutil -replace CFBundleShortVersionString -xml "<string>${_VERSION}</string>" "${_PLIST_INFO}" || CheckLastResult
plutil -replace CFBundleVersion -xml "<string>${_VERSION}</string>" "${_PLIST_INFO}" || CheckLastResult

# ===================== COMPILING =======================
echo "[+] Compiling helper ..."
mkdir -p "${_OUT_DIR}"
cc -D TEAM_IDENTIFIER="\"${_SIGN_CERT}\"" \
        -O2 \
        ${_ARCH_FLAG} \
        -isysroot ${_SDK} \
        -mmacosx-version-min=${_DEPLOY_MIN} \
        -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "${_PLIST_INFO}" \
        -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __launchd_plist -Xlinker "${_PLIST_LAUNCHD}" \
        -o "${_OUT_BINARY}" helper.c \
        ${_CFLAGS}
CheckLastResult

echo "[ ] Done. Helper compiled: '${_BASE_DIR}/${_OUT_BINARY}'"
