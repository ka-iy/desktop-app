package ivpnclient

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strconv"
	"strings"
)

type Logger interface {
	Info(v ...interface{})
	Error(v ...interface{})
}

type noopLogger struct{}

func (noopLogger) Info(v ...interface{})  {}
func (noopLogger) Error(v ...interface{}) {}

// GetTypeName returns the type name of cmd without the package prefix.
// Returns an empty string if cmd is nil.
func GetTypeName(cmd interface{}) string {
	if cmd == nil {
		return ""
	}
	t := reflect.TypeOf(cmd)
	typePath := strings.Split(t.String(), ".")
	if len(typePath) == 0 {
		return ""
	}
	return typePath[len(typePath)-1]
}

// DeserializeCommandBase deserializing to CommandBase object
func DeserializeCommandBase(messageData []byte) (CommandBase, error) {
	var obj CommandBase
	if err := json.Unmarshal(messageData, &obj); err != nil {
		return obj, fmt.Errorf("failed to parse command data: %w", err)
	}
	if len(obj.Command) == 0 {
		return obj, fmt.Errorf("command name is not defined")
	}
	return obj, nil
}

// read port+secret to be able to connect to a daemon
func readDaemonPort(file string) (port int, secret uint64, err error) {
	if len(file) == 0 {
		return 0, 0, fmt.Errorf("connection-info file not defined")
	}

	if _, err := os.Stat(file); err != nil {
		if os.IsNotExist(err) {
			return 0, 0, fmt.Errorf("please, ensure IVPN daemon is running (connection-info not exists)")
		}
		return 0, 0, fmt.Errorf("connection-info check error: %s", err)
	}

	data, err := os.ReadFile(filepath.Clean(file))
	if err != nil {
		return 0, 0, fmt.Errorf("connection-info file read error: %w", err)
	}

	vars := strings.Split(string(data), ":")
	if len(vars) != 2 {
		return 0, 0, fmt.Errorf("failed to parse connection-info")
	}

	port, err = strconv.Atoi(strings.TrimSpace(vars[0]))
	if err != nil {
		return 0, 0, fmt.Errorf("failed to parse connection-info: %w", err)
	}

	secret, err = strconv.ParseUint(strings.TrimSpace(vars[1]), 16, 64)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to parse connection-info: %w", err)
	}

	return port, secret, nil
}

// read paranoid mode secret if file provided and exists
func readParanoidModeSecret(file string) (secret string, err error) {
	if len(file) == 0 {
		return "", nil
	}

	if _, err := os.Stat(file); err != nil {
		if os.IsNotExist(err) {
			return "", nil
		}
	}

	data, err := os.ReadFile(filepath.Clean(file))
	if err != nil {
		return "", fmt.Errorf("paranoid mode secret file read error: %w", err)
	}
	return strings.TrimSpace(string(data)), nil
}

// getConnectionFiles returns the paths to the port file and the paranoid mode secret file based on the current platform.
func getConnectionFiles() (portFile string, paranoidModeSecretFile string, err error) {
	baseDir := ""

	switch runtime.GOOS {
	case "darwin":
		baseDir = "/Library/Application Support/IVPN"

	case "linux":
		baseDir = "/etc/opt/ivpn/mutable"
		if _, err := os.Stat(baseDir); err != nil {
			if snapDir, ok := linuxSnapCommon(); ok {
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
func linuxSnapCommon() (string, bool) {
	const ivpnSnapCommon = "/var/snap/ivpn/common"
	if _, err := os.Stat(ivpnSnapCommon); err == nil {
		return ivpnSnapCommon, true
	}
	return "", false
}
