package ivpnclient

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	"golang.org/x/sys/windows/registry"
)

// getConnectionFiles returns the paths to the port file and the paranoid mode secret file based on the current platform.
func getConnectionFiles() (portFile string, paranoidModeSecretFile string, err error) {
	baseDir := ""

	switch runtime.GOOS {
	case "darwin":
		baseDir = "/Library/Application Support/IVPN"

	case "linux":
		baseDir = "/etc/opt/ivpn/mutable"
		if _, err := os.Stat(baseDir); err != nil {
			if snapDir, err := linuxSnapCommon(); err == nil {
				baseDir = filepath.Join(snapDir, "opt/ivpn/mutable")
			} else {
				return "", "", fmt.Errorf("IVPN mutable directory not found at '%s' and snap installation not detected", baseDir)
			}
		}

	case "windows":
		dir, err := winInstallFolder()
		if err != nil {
			return "", "", err
		}
		baseDir = filepath.Join(dir, "etc")

	default:
		return "", "", fmt.Errorf("unsupported platform: %s", runtime.GOOS)
	}

	portFile = filepath.Join(baseDir, "port.txt")
	paranoidModeSecretFile = filepath.Join(baseDir, "eaa")

	return portFile, paranoidModeSecretFile, nil
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

// winInstallFolder reads the IVPN installation directory from the Windows registry.
func winInstallFolder() (string, error) {
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, `Software\IVPN Client`, registry.QUERY_VALUE)
	if err != nil {
		return "", fmt.Errorf("opening registry key: %w", err)
	}
	defer k.Close()

	val, _, err := k.GetStringValue("")
	if err != nil {
		return "", fmt.Errorf("reading registry default value: %w", err)
	}
	return val, nil
}
