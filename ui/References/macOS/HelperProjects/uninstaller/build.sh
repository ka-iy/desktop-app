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

# The Apple DevID certificate which will be used to sign IVPN Agent (Daemon) binary
# The helper will check IVPN Agent signature with this value
_SIGN_CERT="" # E.g. "WXXXXXXXXN". Specific value can be passed by command-line argument: -c <APPLE_DEVID_SERT>
while getopts ":c:" opt; do
  case $opt in
    c) _SIGN_CERT="$OPTARG"
    ;;
  esac
done

if [ -z "${_SIGN_CERT}" ]; then
  echo "Usage:"
  echo "    $0 -c <APPLE_DEVID_CERTIFICATE>"
  echo "    Example: $0 -c WXXXXXXXXN"
  exit 1
fi

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

if [ ! -f "../helper/_out/${ARCH_TARGET}/net.ivpn.client.Helper" ]; then
  echo " File not exists '../helper/_out/${ARCH_TARGET}/net.ivpn.client.Helper'. Please, compile helper project first."
  exit 1
fi

rm -fr bin/${ARCH_TARGET}
CheckLastResult

echo "[ ] *** Compiling IVPN Installer / Uninstaller ***"

echo "[+] IVPN Installer: updating certificate info in .plist ..."
echo "    Apple DevID certificate: '${_SIGN_CERT}'"
plutil -replace SMPrivilegedExecutables -xml \
        "<dict> \
      		<key>net.ivpn.client.Helper</key> \
      		<string>identifier net.ivpn.client.Helper and certificate leaf[subject.OU] = ${_SIGN_CERT}</string> \
      	</dict>" "IVPN Installer-Info.plist" || CheckLastResult
plutil -replace SMPrivilegedExecutables -xml \
        "<dict> \
          <key>net.ivpn.client.Helper</key> \
          <string>identifier net.ivpn.client.Helper and certificate leaf[subject.OU] = ${_SIGN_CERT}</string> \
        </dict>" "IVPN Uninstaller-Info.plist" || CheckLastResult

echo "[+] IVPN Installer: compiling ..."
mkdir -p bin/${ARCH_TARGET}
CheckLastResult

cc ${_ARCH_FLAG} -isysroot ${_SDK} \
    -framework Foundation \
    -mmacosx-version-min=${_DEPLOY_MIN} \
    -D IS_INSTALLER=0 \
    -framework ServiceManagement \
    -framework Security \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist \
        -Xlinker "IVPN Uninstaller-Info.plist" \
    uninstaller.c -o "bin/${ARCH_TARGET}/IVPN Uninstaller"
CheckLastResult

cc ${_ARCH_FLAG} -isysroot ${_SDK} \
    -framework Foundation \
    -mmacosx-version-min=${_DEPLOY_MIN} \
    -D IS_INSTALLER=1 \
    -framework ServiceManagement \
    -framework Security \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist \
        -Xlinker "IVPN Installer-Info.plist" \
    uninstaller.c -o "bin/${ARCH_TARGET}/IVPN Installer"
CheckLastResult

echo "[+] IVPN Installer: IVPN Installer.app ..."
mkdir -p "bin/${ARCH_TARGET}/IVPN Installer.app/Contents/Library/LaunchServices" || CheckLastResult
mkdir -p "bin/${ARCH_TARGET}/IVPN Installer.app/Contents/MacOS" || CheckLastResult
cp "../helper/_out/${ARCH_TARGET}/net.ivpn.client.Helper" "bin/${ARCH_TARGET}/IVPN Installer.app/Contents/Library/LaunchServices" || CheckLastResult
cp "bin/${ARCH_TARGET}/IVPN Installer" "bin/${ARCH_TARGET}/IVPN Installer.app/Contents/MacOS" || CheckLastResult
cp "etc/install.sh" "bin/${ARCH_TARGET}/IVPN Installer.app/Contents/MacOS" || CheckLastResult
cp "IVPN Installer-Info.plist" "bin/${ARCH_TARGET}/IVPN Installer.app/Contents/Info.plist" || CheckLastResult

echo "[+] IVPN Installer: IVPN Uninstaller.app ..."
mkdir -p "bin/${ARCH_TARGET}/IVPN Uninstaller.app/Contents/MacOS" || CheckLastResult
cp "bin/${ARCH_TARGET}/IVPN Uninstaller" "bin/${ARCH_TARGET}/IVPN Uninstaller.app/Contents/MacOS" || CheckLastResult
cp "IVPN Uninstaller-Info.plist" "bin/${ARCH_TARGET}/IVPN Uninstaller.app/Contents/Info.plist" || CheckLastResult

echo "[ ] IVPN Installer: Done"
echo "    ${_SCRIPT_DIR}/bin/${ARCH_TARGET}/IVPN Installer.app"
echo "    ${_SCRIPT_DIR}/bin/${ARCH_TARGET}/IVPN Uninstaller.app"

cd ${_BASE_DIR}
