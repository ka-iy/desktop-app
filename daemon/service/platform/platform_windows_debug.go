//
//  Daemon for IVPN Client Desktop
//  https://github.com/ivpn/desktop-app
//
//  Created by Stelnykovych Alexandr.
//  Copyright (c) 2023 IVPN Limited.
//
//  This file is part of the Daemon for IVPN Client Desktop.
//
//  The Daemon for IVPN Client Desktop is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The Daemon for IVPN Client Desktop is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License
//  along with the Daemon for IVPN Client Desktop. If not, see <https://www.gnu.org/licenses/>.
//

//go:build windows && debug
// +build windows,debug

package platform

import (
	"fmt"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strings"
)

// initialize all constant values (e.g. servicePortFile) which can be used in external projects (IVPN CLI)
func doInitConstantsForBuild() {
	servicePortFile = `C:/Program Files/IVPN Client/etc/port.txt`
	if err := os.MkdirAll(filepath.Dir(servicePortFile), os.ModePerm); err != nil {
		fmt.Printf("!!! DEBUG VERSION !!! ERROR	: '%s'\n", servicePortFile)
		servicePortFile = ""
	}
}

func doOsInitForBuild() {
	installDir := getInstallDir()

	// VS Debug output folder: x64 for amd64, ARM64 for arm64
	_vsArchDir := "x64"
	_archDir := "x86_64"
	if runtime.GOARCH == "arm64" {
		_vsArchDir = "ARM64"
		_archDir = "arm64"
	}

	wfpDllPath = path.Join(installDir, "Native Projects/bin/Debug/"+_vsArchDir+"/IVPN Firewall Native.dll")
	nativeHelpersDllPath = path.Join(installDir, "Native Projects/bin/Debug/"+_vsArchDir+"/IVPN Helpers Native.dll")
	splitTunDriverPath = path.Join(installDir, "SplitTunnelDriver/"+_archDir+"/ivpn-split-tunnel.sys")

	// In debug builds (source tree), vendor binaries live in arch subdirs
	openVpnBinaryPath = path.Join(installDir, "OpenVPN", _archDir, "openvpn.exe")
	obfsproxyStartScript = path.Join(installDir, "OpenVPN", "obfsproxy", _archDir, "obfs4proxy.exe")
	v2rayBinaryPath = path.Join(installDir, "v2ray", _archDir, "v2ray.exe")
	wgBinaryPath = path.Join(installDir, "WireGuard", _archDir, "wireguard.exe")
	wgToolBinaryPath = path.Join(installDir, "WireGuard", _archDir, "wg.exe")
	dnscryptproxyBinPath = path.Join(installDir, "dnscrypt-proxy", _archDir, "dnscrypt-proxy.exe")
	kemHelperBinaryPath = path.Join(installDir, "kem", _archDir, "kem-helper.exe")

	fmt.Println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	fmt.Printf("!!! DEBUG VERSION !!! wfpDllPath            : '%s'\n", wfpDllPath)
	fmt.Printf("!!! DEBUG VERSION !!! nativeHelpersDllPath  : '%s'\n", nativeHelpersDllPath)
	fmt.Printf("!!! DEBUG VERSION !!! servicePortFile       : '%s'\n", servicePortFile)
	fmt.Println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
}

func getInstallDir() string {
	installDir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		panic(fmt.Sprintf("Failed to obtain folder of current binary: %s", err.Error()))
	}

	if len(os.Args) > 2 {
		firstArg := strings.Split(os.Args[1], "=")
		if len(firstArg) == 2 && firstArg[0] == "-debug_install_dir" {
			installDir = firstArg[1]
		}
	}

	installDir = strings.ReplaceAll(installDir, `\`, `/`)

	// When running tests, the installDir is detected as a dir where test located
	// we need to point installDir to project root
	// Therefore, we cutting rest after "desktop-app/daemon"
	rootDir := "desktop-app/daemon"
	if idx := strings.LastIndex(installDir, rootDir); idx > 0 {
		installDir = installDir[:idx+len(rootDir)]
	}

	installDir = path.Join(installDir, "References/Windows")
	return installDir
}

func getEtcDirCommon() string {
	return path.Join(getEtcDir(), "../../common/etc")
}
