package portmaster

import (
	"net"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/ivpn/desktop-app/daemon/logger"
)

const (
	APIEndpointPing = "http://127.0.0.1:817/api/v1/interop/ping?message=IVPN%20Client%20is%20alive"
)

var log *logger.Logger

func init() {
	log = logger.NewLogger("pm")
}

var (
	pingRunning    atomic.Bool
	pingSuccessful atomic.Bool
)

// WasPingSuccessful returns true if the ping (http request to APIEndpointPing) was successful.
// This can be treated as an indication that the Portmaster API is reachable and responsive.
func WasPingSuccessful() bool {
	return pingSuccessful.Load()
}

// PingPortmaster sends a ping request to the Portmaster API to notify it that the IVPN Client is alive.
// The response is intentionally ignored.
// This function have to be called on IVPN Client startup, to inform Portmaster that the IVPN Client is running.
func PingPortmaster() {
	// Run in a separate goroutine to avoid blocking the caller.
	// The returned error is intentionally discarded — this is a best-effort notification.
	go func() { _ = pingPortmaster() }()
}

func pingPortmaster() error {
	if !pingRunning.CompareAndSwap(false, true) {
		return nil // A ping is already running, skip this one.
	}
	defer pingRunning.Store(false)

	// Portmaster listens on loopback, so the dialer is explicitly bound to loopback.
	dialer := &net.Dialer{
		LocalAddr: &net.TCPAddr{IP: net.ParseIP("127.0.0.1")},
	}

	transport := &http.Transport{
		DialContext: dialer.DialContext,
	}

	client := &http.Client{
		Transport: transport,
		Timeout:   5 * time.Second,
	}

	resp, err := client.Get(APIEndpointPing)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	log.Info("Portmaster ping succeeded")
	pingSuccessful.Store(true)
	return nil
}
