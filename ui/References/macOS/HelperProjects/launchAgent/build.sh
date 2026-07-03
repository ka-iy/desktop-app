#!/bin/bash

#save current dir
_BASE_DIR="$( pwd )"
_SCRIPT=`basename "$0"`
#enter the script folder
cd "$(dirname "$0")"

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

_OUT_FOLDER="_out/${ARCH_TARGET}"
_OUT_BINARY="${_OUT_FOLDER}/net.ivpn.LaunchAgent"
_PATH_XPC_SOURCES="../../../../../daemon/wifiNotifier/darwin/agent_xpc"

mkdir -p ${_OUT_FOLDER}
# ===================== COMPILING =======================
echo "[+] Compiling helper ..."
clang -Wall -O2 \
    ${_ARCH_FLAG} \
    -isysroot ${_SDK} \
    -mmacosx-version-min=${_DEPLOY_MIN} \
    -I${_PATH_XPC_SOURCES} \
		-framework Foundation -framework CoreLocation -framework CoreWLAN  -framework SystemConfiguration \
		-o ${_OUT_BINARY} main.m wifi.m ${_PATH_XPC_SOURCES}/xpc_client.m

if ! [ $? -eq 0 ]; then #check result of last command
  echo "FAILED"
  exit 1
fi

 echo "[ ] Done. Compiled binary: '${_BASE_DIR}/${_OUT_BINARY}'"

#daemon/wifiNotifier/darwin/agent_xpc
#ui/References/macOS/HelperProjects/launchAgent/