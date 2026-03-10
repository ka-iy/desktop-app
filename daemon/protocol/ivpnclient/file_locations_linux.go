//go:build linux
// +build linux

package ivpnclient

import (
	"fmt"
	"os"
	"path/filepath"
)

func getPortFileBaseDir() (baseDir string, err error) {
	baseDir = "/etc/opt/ivpn/mutable"
	if _, err := os.Stat(baseDir); err != nil {
		if snapDir, err := linuxSnapCommon(); err == nil {
			baseDir = filepath.Join(snapDir, "opt/ivpn/mutable")
		} else {
			return "", fmt.Errorf("IVPN mutable directory not found at '%s' and snap installation not detected", baseDir)
		}
	}
	return baseDir, nil
}

// linuxSnapCommon returns the IVPN snap's common data directory if the snap is installed.
// Snapd always exposes it at /var/snap/<name>/common on the host, accessible from anywhere.
func linuxSnapCommon() (string, error) {
	const ivpnSnapCommon = "/var/snap/ivpn/common"
	if _, err := os.Stat(ivpnSnapCommon); err != nil {
		return "", fmt.Errorf("IVPN snap common directory not found at %q", ivpnSnapCommon)
	}
	return ivpnSnapCommon, nil
}
