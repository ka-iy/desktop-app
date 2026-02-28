//go:build darwin
// +build darwin

package ivpnclient

func getPortFileBaseDir() (baseDir string, err error) {
	baseDir = "/Library/Application Support/IVPN"
	return baseDir, nil
}
