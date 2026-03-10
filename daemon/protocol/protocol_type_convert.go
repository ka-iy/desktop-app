package protocol

import (
	"github.com/ivpn/desktop-app/daemon/protocol/ivpnclient"
	"github.com/ivpn/desktop-app/daemon/service/dns"
	service_types "github.com/ivpn/desktop-app/daemon/service/types"
)

func convertIvpnclientType_Dns(dnsCfg ivpnclient.DnsSettings) dns.DnsSettings {
	internalCfg := dns.DnsSettings{Servers: make([]dns.DnsServerConfig, len(dnsCfg.Servers))}
	for i, s := range dnsCfg.Servers {
		internalCfg.Servers[i] = dns.DnsServerConfig{
			Address:    s.Address,
			Encryption: dns.DnsEncryption(s.Encryption),
			Template:   s.Template,
		}
	}
	return internalCfg
}

func convertInternalType_AntiTracker(atMetadata ivpnclient.AntiTrackerMetadata) service_types.AntiTrackerMetadata {
	return service_types.AntiTrackerMetadata{
		Enabled:                  atMetadata.Enabled,
		Hardcore:                 atMetadata.Hardcore,
		AntiTrackerBlockListName: atMetadata.AntiTrackerBlockListName,
	}
}
