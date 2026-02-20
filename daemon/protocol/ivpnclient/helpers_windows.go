//go:build windows

package ivpnclient

import (
	"fmt"

	"golang.org/x/sys/windows/registry"
)

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
