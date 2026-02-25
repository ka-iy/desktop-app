package interoperability

import (
	"sync/atomic"

	"github.com/ivpn/desktop-app/daemon/interoperability/portmaster"
	"github.com/ivpn/desktop-app/daemon/protocol/ivpnclient"
)

var (
	// true if Portmaster client is currently connected to the IVPN Client, false otherwise
	portmasterConnected atomic.Bool
	// true if Portmaster client was detected at least once since the IVPN Client was started, false otherwise
	portmasterWasDetected atomic.Bool
)

func ClientConnected(clienType ivpnclient.ClientTypeEnum) {
	if clienType == ivpnclient.ClientPortmaster {
		portmasterConnected.Store(true)
		portmasterWasDetected.Store(true)
	}
}

func ClientDisconnected(clientType ivpnclient.ClientTypeEnum) {
	if clientType == ivpnclient.ClientPortmaster {
		portmasterConnected.Store(false)
	}
}

// Ping - Ping interoperable applications (e.g. Portmaster) to notify them that the IVPN Client is alive.
// This normally have to be called on IVPN Client startup, to inform Portmaster that the IVPN Client is running.
func Ping() {
	portmaster.PingPortmaster()
}

// PingDetectedApps - Ping already detected interoperable applications (e.g. Portmaster)
// This is a fail-safe action for situations when an established Portmaster connection was dropped for some unexpected reason.
// We notify it: "Hey! IVPN Client is still running and you can connect to it again!".
func PingDetectedApps() {
	if !portmasterWasDetected.Load() && !portmaster.WasPingSuccessful() {
		return // no need to ping if Portmaster was not detected
	}
	if portmasterConnected.Load() {
		return // no need to ping if Portmaster client is connected
	}
	portmaster.PingPortmaster()
}
