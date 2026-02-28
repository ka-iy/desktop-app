package ivpnclient

import (
	"path/filepath"
)

// getConnectionFiles returns the paths to the port file and the paranoid mode secret file based on the current platform.
func getConnectionFiles() (portFile string, paranoidModeSecretFile string, err error) {
	baseDir, err := getPortFileBaseDir()
	if err != nil {
		return "", "", err
	}

	portFile = filepath.Join(baseDir, "port.txt")
	paranoidModeSecretFile = filepath.Join(baseDir, "eaa")

	return portFile, paranoidModeSecretFile, nil
}
