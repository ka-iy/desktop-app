#!/bin/sh

cd "$(dirname "$0")"

VERSION=""
DATE="$(date "+%Y-%m-%d")"
COMMIT="$(git rev-list -1 HEAD)"

while getopts ":v:" opt; do
  case $opt in
    v) VERSION="$OPTARG"
    ;;
#    \?) echo "Invalid option -$OPTARG" >&2
#   ;;
  esac
done

echo "############################################"
echo "### Building IVPN Daemon"
echo "### OpenVPN and WireGuard will be also recompiled if they are not exists"

# ====== Architecture setup ======
_HOST_ARCH="$(uname -m)"
ARCH_TARGET="${ARCH_TARGET:-$_HOST_ARCH}"
case "$ARCH_TARGET" in
  arm64)
    _ARCH_FLAG="-arch arm64"
    _GOARCH="arm64"
    _OPENSSL_TARGET="darwin64-arm64-cc"
    _AUTOCONF_HOST="aarch64-apple-darwin"
    ;;
  x86_64)
    _ARCH_FLAG="-arch x86_64"
    _GOARCH="amd64"
    _OPENSSL_TARGET="darwin64-x86_64-cc"
    _AUTOCONF_HOST="x86_64-apple-darwin"
    ;;
  *)
    echo "ERROR: Unsupported ARCH_TARGET='$ARCH_TARGET'. Use 'arm64' or 'x86_64'."
    exit 1
    ;;
esac
_DEPLOY_MIN="12.0"
_SDK="$(xcrun --sdk macosx --show-sdk-path)"
_CC="$(xcrun -f clang) ${_ARCH_FLAG} -isysroot ${_SDK}"
_CXX="$(xcrun -f clang++) ${_ARCH_FLAG} -isysroot ${_SDK}"
export ARCH_TARGET
echo "    ARCH_TARGET: ${ARCH_TARGET}"
# ====== End architecture setup ======

if [ "$#" -eq 0 ]
then
  echo "### Possible arguments:"
  echo "###   -norebuild    - do not rebuild openVPN and WireGuard binaries is they already compiled"
  echo "###   -debug        - compile IVPN Daemon in debug mode"
  echo "###   -libivpn      - use XPC listener for notifying clients about daemon connection port (latest IVPN UI not using XPC)"
  echo "###   -wifi         - enable wifi support (do not ask 'Enable WIFI support?' question before demon build start)"
fi
echo "############################################"

if [[ ! -f "../_deps/${ARCH_TARGET}/openvpn_inst/bin/openvpn" ]] || [[ ! -f "../_deps/${ARCH_TARGET}/wg_inst/wg" ]] || [[ ! -f "../_deps/${ARCH_TARGET}/wg_inst/wireguard-go" ]]
then
  echo "Please, check/modify required versions at the begining of scripts:"
  if [[ ! -f "../_deps/${ARCH_TARGET}/openvpn_inst/bin/openvpn" ]]
  then
    echo "    build-openvpn.sh"
  fi

  if [[ ! -f "../_deps/${ARCH_TARGET}/wg_inst/wg" ]] || [[ ! -f "../_deps/${ARCH_TARGET}/wg_inst/wireguard-go" ]]
  then
    echo "    build-wireguard.sh"
  fi

  if [ -z "${IVPN_BUILD_SKIP_PROMPT}" ] && [ -z "${GITHUB_ACTIONS}" ]; then
    read -p "Press enter to start ..."
  fi
fi

# Exit immediately if a command exits with a non-zero status.
set -e

function BuildOpenVPN
{
  echo "############################################"
  echo "### OpenVPN"
  echo "############################################"
  ./build-openvpn.sh
}

function BuildWireGuard
{
  echo "############################################"
  echo "### WireGuard"
  echo "############################################"
  ./build-wireguard.sh
}

function BuildObfs4proxy
{
  echo "############################################"
  echo "### obfs4proxy"
  echo "############################################"
  ./build-obfs4proxy.sh
}

function BuildV2Ray
{
  echo "############################################"
  echo "### V2Ray"
  echo "############################################"
  ./build-v2ray.sh
}

function BuildDnscryptProxy
{
  echo "############################################"
  echo "### dnscrypt-proxy"
  echo "############################################"
  ./build-dnscrypt-proxy.sh
}

function BuildKemHelper
{
  echo "############################################"
  echo "### kem-helper"
  echo "############################################"
  ./build-kem-helper.sh
}

if [ ! -z "$GITHUB_ACTIONS" ]; then
  echo "! GITHUB_ACTIONS detected ! It is just a build test."
  echo "! Skipped compilation of third-party dependencies: OpenVPN, WireGuard, obfs4proxy, dnscrypt-proxy ..."
else
  if [[ "$@" == *"-norebuild"* ]]
  then
      # check if we need to compile openvpn
      if [[ ! -f "../_deps/${ARCH_TARGET}/openvpn_inst/bin/openvpn" ]]
      then
        echo "OpenVPN not compiled"
        BuildOpenVPN
      else
        echo "OpenVPN already compiled. Skipping build."
      fi

      # check if we need to compile WireGuard
      if [[ ! -f "../_deps/${ARCH_TARGET}/wg_inst/wg" ]] || [[ ! -f "../_deps/${ARCH_TARGET}/wg_inst/wireguard-go" ]]
      then
        echo "WireGuard not compiled"
        BuildWireGuard
      else
        echo "WireGuard already compiled. Skipping build."
      fi

      # check if we need to compile obfs4proxy
      if [[ ! -f "../_deps/${ARCH_TARGET}/obfs4proxy_inst/obfs4proxy" ]]
      then
        echo "obfs4proxy not compiled"
        BuildObfs4proxy
      else
        echo "obfs4proxy already compiled. Skipping build."
      fi

      # check if we need to compile v2ray
      if [[ ! -f "../_deps/${ARCH_TARGET}/v2ray_inst/v2ray" ]]
      then
        echo "V2Ray not compiled"
        BuildV2Ray
      else
        echo "V2Ray already compiled. Skipping build."
      fi

      # check if we need to compile dnscrypt-proxy
      if [[ ! -f "../_deps/${ARCH_TARGET}/dnscryptproxy_inst/dnscrypt-proxy" ]]
      then
        echo "dnscrypt-proxy not compiled"
        BuildDnscryptProxy
      else
        echo "dnscrypt-proxy already compiled. Skipping build."
      fi

      # check if we need to compile kem-helper
      if [[ ! -f "../_deps/${ARCH_TARGET}/kem-helper/kem-helper-bin/kem-helper" ]]
      then
        echo "kem-helper not compiled"
        BuildKemHelper
      else
        echo "kem-helper already compiled. Skipping build."
      fi

  else
    # recompile openvpn, WireGuard, obfs4proxy, dnscrypt-proxy ...
    BuildOpenVPN
    BuildWireGuard
    BuildObfs4proxy
    BuildV2Ray
    BuildDnscryptProxy
    BuildKemHelper
  fi
fi
# updating servers.json
./update-servers.sh

echo "======================================================"
echo "=============== IVPN Agent ==========================="
echo "======================================================"
echo "Version: $VERSION"
echo "Date   : $DATE"
echo "Commit : $COMMIT"

cd ../../../

BUILDTAGS_DEBUG=""
BUILDTAGS_NOWIFI=""
BUILDTAGS_USE_LIBVPN=""

if [[ "$@" == *"-debug"* ]]
then
  BUILDTAGS_DEBUG="debug"
fi

if [[ "$@" == *"-libivpn"* ]]
then
  BUILDTAGS_USE_LIBVPN="libivpn"
fi

if [[ "$@" != *"-wifi"* ]]
then
  echo ""
  echo "Enable WIFI support?"
  echo "(this will lead to some additional library dependencies for the final binary)"
  read -p "[y\n]? (N - default): " yn
  case $yn in
      [Yy]* )
          ;;
      [Nn]* )
        BUILDTAGS_NOWIFI="nowifi"
        ;;
      * )
        BUILDTAGS_NOWIFI="nowifi"
        ;;
  esac
fi

mkdir -p "bin/${ARCH_TARGET}"

CC="${_CC}" \
CGO_CFLAGS="-mmacosx-version-min=${_DEPLOY_MIN} ${_ARCH_FLAG} -isysroot ${_SDK}" \
CGO_LDFLAGS="-mmacosx-version-min=${_DEPLOY_MIN} ${_ARCH_FLAG} -isysroot ${_SDK}" \
GOOS=darwin GOARCH="${_GOARCH}" CGO_ENABLED=1 \
go build \
    -tags "${BUILDTAGS_NOWIFI} ${BUILDTAGS_USE_LIBVPN} ${BUILDTAGS_DEBUG}" \
    -o "bin/${ARCH_TARGET}/IVPN Agent" \
    -trimpath \
    -ldflags "-s -w -X github.com/ivpn/desktop-app/daemon/version._version=$VERSION -X github.com/ivpn/desktop-app/daemon/version._commit=$COMMIT -X github.com/ivpn/desktop-app/daemon/version._time=$DATE"

echo "Compiled daemon binary: '$(pwd)/bin/${ARCH_TARGET}/IVPN Agent'"
