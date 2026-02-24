package portmaster

import (
	"net"
	"net/http"
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

// PingPortmaster sends a ping request to the Portmaster API to notify it that the IVPN Client is alive.
// The response is intentionally ignored.
// Portmaster listens on loopback, so the dialer is explicitly bound to loopback.
func PingPortmaster() {
	// Run in a separate goroutine to avoid blocking the caller.
	// The returned error is intentionally discarded — this is a best-effort notification.
	go func() { _ = pingPortmaster() }()
}

func pingPortmaster() error {
	// Use a custom dialer that explicitly binds to 127.0.0.1 to ensure
	dialer := &net.Dialer{
		Timeout:   2 * time.Second,
		LocalAddr: &net.TCPAddr{IP: net.ParseIP("127.0.0.1")},
	}

	transport := &http.Transport{
		DialContext: dialer.DialContext,
	}

	client := &http.Client{
		Transport: transport,
		Timeout:   2 * time.Second,
	}

	resp, err := client.Get(APIEndpointPing)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	log.Info("Portmaster ping succeeded")

	return nil
}
