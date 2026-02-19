package ivpnclient

type DnsEncryption int

const (
	EncryptionNone         DnsEncryption = 0
	EncryptionDnsOverTls   DnsEncryption = 1
	EncryptionDnsOverHttps DnsEncryption = 2
)

type DnsServerConfig struct {
	Address    string        // IP address of the DNS server
	Encryption DnsEncryption // Encryption type (None, DoH, DoT)
	Template   string        // DoH/DoT template
}

type DnsSettings struct {
	// List of DNS servers specified in order of preference
	Servers []DnsServerConfig
}

type AntiTrackerMetadata struct {
	Enabled                  bool
	Hardcore                 bool
	AntiTrackerBlockListName string
}

// SetAlternateDns request to set custom DNS
type SetAlternateDns struct {
	RequestBase
	AntiTracker AntiTrackerMetadata
	Dns         DnsSettings // If 'AntiTracker' is enabled - his parameter will be ignored
}

// SetManualDNS - sets manual DNS for current VPN connection
func (c *Client) SetManualDNS(dnsCfg DnsSettings, antiTracker AntiTrackerMetadata) error {
	req := SetAlternateDns{Dns: dnsCfg, AntiTracker: antiTracker}
	var resp EmptyResp
	if err := c.SendRecv(&req, &resp); err != nil {
		return err
	}

	return nil
}

//
// TODO: more client commands can be added here in the future ...
//
