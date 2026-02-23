package service

import (
	"fmt"
	"net"
	"strings"

	"github.com/ivpn/desktop-app/daemon/service/dns"
	"github.com/ivpn/desktop-app/daemon/service/types"
)

// GetSettingsManualDNS returns current manual DNS settings from service connection parameters
func (s *Service) GetSettingsManualDNS() dns.DnsSettings {
	return s.GetConnectionParams().ManualDNS
}

// GetSettingsAntiTracker returns current AntiTracker settings from service connection parameters
func (s *Service) GetSettingsAntiTracker() types.AntiTrackerMetadata {
	// Get AntiTracker DNS settings. If error - use default date and ignore error
	retAtMetadata, err := s.normalizeAntiTrackerBlockListName(s.GetConnectionParams().Metadata.AntiTracker)
	if err != nil {
		log.Error(fmt.Sprintf("failed to normalize AntiTracker block list name: %v (using '%s')", err, retAtMetadata.AntiTrackerBlockListName))
	}
	return retAtMetadata
}

// SetDnsOverride update the custom DNS parameters in service settings
// and apply new DNS value for current VPN connection (if it is connected)
func (s *Service) SetDnsOverride(
	dnsCfg dns.DnsSettings,
	antiTracker types.AntiTrackerMetadata) (retErr error) {

	var err error

	// Split-Tunneling related part
	if !dnsCfg.IsEmpty() || antiTracker.Enabled {
		prefs := s.Preferences()
		if prefs.IsInverseSplitTunneling() && prefs.SplitTunnelAnyDns {
			return fmt.Errorf("custom DNS or AntiTracker cannot be enabled while allowing all DNS for Inverse Split Tunnel mode; please block non-IVPN DNS first in the Inverse Split Tunnel configuration")
		}
	}
	isChanged := false
	defer func() {
		if isChanged {
			// Apply Firewall rule (for Inverse Split Tunnel): allow DNS requests only to IVPN servrers or to manually defined server
			if err := s.splitTunnelling_ApplyConfig(); err != nil {
				log.Error(err)
			}
		}
	}()

	// Update manual DNS options in service settings
	isChanged, err = s.saveDnsParams(dnsCfg, antiTracker)
	if err != nil {
		return err
	}

	// Apply new DNS settings for current VPN connection (if it is connected)
	return s.applyDnsOverride()
}

// saveDnsParams just saves DNS parameters into service connection settings
func (s *Service) saveDnsParams(dnsCfg dns.DnsSettings, antiTrackerCfg types.AntiTrackerMetadata) (updated bool, retErr error) {
	defaultParams := s.GetConnectionParams()

	dnsEqual := defaultParams.ManualDNS.Equal(dnsCfg)
	attEqual := defaultParams.Metadata.AntiTracker.Equal(antiTrackerCfg)

	if dnsEqual && attEqual {
		return false, nil
	}

	if !attEqual {
		at, err := s.normalizeAntiTrackerBlockListName(antiTrackerCfg)
		if err != nil {
			return false, err
		}
		antiTrackerCfg = at
	}

	// save DNS and AntiTracker default metadata
	defaultParams.ManualDNS = dnsCfg
	defaultParams.Metadata.AntiTracker = antiTrackerCfg

	return true, s.setConnectionParams(defaultParams)
}

// getActiveDNS() returns DNS active settings for current VPN connection:
// - if any custom DNS settings defined (either manual DNS or AntiTracker) - returns this custom DNS configuration;
// - else returns default DNS configuration for current VPN connection
// *Note! If VPN disconnected - returns empty data
func (s *Service) getActiveDNS() (dnsCfg dns.DnsSettings, err error) {
	vpnObj := s._vpn
	if vpnObj == nil {
		return dns.DnsSettings{}, nil //VPN DISCONNECTED
	}
	// Get manual DNS settings
	manualDns, err := s.getEffectiveDnsOverride()
	if err != nil {
		return dns.DnsSettings{}, err
	}
	if !manualDns.IsEmpty() {
		return manualDns, nil
	}
	// If manual DNS settings not defined - return default DNS for current VPN connection
	return dns.DnsSettingsCreate(vpnObj.DefaultDNS()), nil
}

// getEffectiveDnsOverride returns the DNS override settings to apply for the current VPN connection.
// Priority order (highest to lowest):
//   - TempPrioritizedDnsServer, if defined
//   - AntiTracker DNS, if AntiTracker is enabled
//   - ManualDNS from connection parameters
//
// Empty DNS settings indicate that no override is needed and the VPN connection's own default DNS should be used.
func (s *Service) getEffectiveDnsOverride() (realDnsValue dns.DnsSettings, err error) {
	defaultParams := s.GetConnectionParams()

	// If temporary prioritized DNS server is defined - use it (it has the highest priority)
	//if addr := defaultParams.Metadata.TempPrioritizedDnsServer.Address(); addr != nil {
	//	return dns.DnsSettingsCreate(addr), nil
	//}

	// If AntiTracker enabled - return DNS of AntiTracker server
	antiTrackerCfg := defaultParams.Metadata.AntiTracker
	if antiTrackerCfg.Enabled {
		return s.getAntiTrackerDns(antiTrackerCfg.Hardcore, antiTrackerCfg.AntiTrackerBlockListName)
	}

	// Return default manual DNS value
	return defaultParams.ManualDNS, nil
}

// applyDnsOverride applies current manual DNS settings for active VPN connection (if exists)
// This function is used for ensuring that DNS settings are applied correctly
// (e.g. after VPN reconnect or when DNS settings was changed while VPN is connected)
// Note: this have no effect if VPN is not connected
func (s *Service) applyDnsOverride() error {
	vpn := s._vpn
	if vpn == nil {
		return nil
	}
	dns, err := s.getEffectiveDnsOverride()
	if err != nil {
		return err
	}

	if dns.IsEmpty() {
		return vpn.ResetManualDNS()
	}
	return vpn.SetManualDNS(dns)
}

// Normalize AntiTracker block list name:
// - if antiTrackerPlusList not defined - return default value
// - if antiTrackerPlusList defined - check if it is valid; if not valid - return default value and error
func (s *Service) normalizeAntiTrackerBlockListName(antiTracker types.AntiTrackerMetadata) (types.AntiTrackerMetadata, error) {
	var retError error

	atBlistName := strings.ToLower(strings.TrimSpace(antiTracker.AntiTrackerBlockListName))
	// check if block list name is known
	if atBlistName != "" {
		servers, err := s.ServersList()
		if err == nil {
			for _, atp_svr := range servers.Config.AntiTrackerPlus.DnsServers {
				if strings.ToLower(strings.TrimSpace(atp_svr.Name)) == atBlistName {
					// Block-list name is OK. Just ensure to use correct case
					antiTracker.AntiTrackerBlockListName = strings.TrimSpace(atp_svr.Name)
					return antiTracker, nil
				}
			}
		}

		retError = fmt.Errorf("unexpected DNS block list name: '%s'", antiTracker.AntiTrackerBlockListName)
	}

	// Set default block list name (if empty)
	if tmpDns, err := s.getAntiTrackerDns(antiTracker.Hardcore, ""); err == nil {
		if tmpAt, err := s.getAntiTrackerInfo(tmpDns); err == nil {
			antiTracker.AntiTrackerBlockListName = tmpAt.AntiTrackerBlockListName
		}
	}

	return antiTracker, retError
}

// Get DNS server according to AntiTracker parameters
// 'isHardcore' - if true - get DNS for Hardcore AntiTracker, otherwise - for default AntiTracker
// 'antiTrackerPlusList' - if defined - use AntiTracker Plus DNS server with this block list name; otherwise - use old-style AntiTracker DNS
func (s *Service) getAntiTrackerDns(isHardcore bool, antiTrackerPlusList string) (dnsCfg dns.DnsSettings, err error) {
	defer func() {
		if dnsCfg.IsEmpty() && err == nil {
			err = fmt.Errorf("unable to determine AntiTracker DNS")
		}
	}()
	servers, err := s.ServersList()
	if err != nil {
		return dns.DnsSettings{}, fmt.Errorf("failed to determine AntiTracker parameters: %w", err)
	}

	// AntiTracker Plus list
	atListName := strings.ToLower(strings.TrimSpace(antiTrackerPlusList))
	if len(atListName) == 0 {
		// if block list name not defined - use default AntiTracker block list "Basic"
		atListName = "basic"
	}

	// If block list name defined - try to find it in AntiTracker Plus lists
	for _, atp_svr := range servers.Config.AntiTrackerPlus.DnsServers {
		if strings.ToLower(strings.TrimSpace(atp_svr.Name)) == atListName {
			if isHardcore {
				return dns.DnsSettingsCreate(net.ParseIP(atp_svr.Hardcore)), nil
			}
			return dns.DnsSettingsCreate(net.ParseIP(atp_svr.Normal)), nil
		}
	}

	// If AntiTracker Plus block list not found - ignore 'antiTrackerPlusList' and use old-style AntiTracker DNS
	if isHardcore {
		return dns.DnsSettingsCreate(net.ParseIP(servers.Config.Antitracker.Hardcore.IP)), nil
	}
	return dns.DnsSettingsCreate(net.ParseIP(servers.Config.Antitracker.Default.IP)), nil
}

// Get AntiTracker info according to DNS settings
func (s *Service) getAntiTrackerInfo(dnsVal dns.DnsSettings) (types.AntiTrackerMetadata, error) {
	// If uses encrypted DNS or multiple DNS servers - it is custom DNS, no AntiTracker info
	if dnsVal.IsEmpty() || dnsVal.UseEncryption() || len(dnsVal.Servers) != 1 {
		return types.AntiTrackerMetadata{}, nil
	}

	servers, err := s.ServersList()
	if err != nil {
		return types.AntiTrackerMetadata{}, fmt.Errorf("failed to determine AntiTracker parameters: %w", err)
	}

	dnsHost := strings.ToLower(strings.TrimSpace(dnsVal.Servers[0].Address))
	if dnsHost == "" {
		return types.AntiTrackerMetadata{}, nil
	}

	// Check AntiTracker Plus lists
	for _, atp_svr := range servers.Config.AntiTrackerPlus.DnsServers {
		if strings.EqualFold(dnsHost, strings.TrimSpace(atp_svr.Normal)) {
			return types.AntiTrackerMetadata{Enabled: true, Hardcore: false, AntiTrackerBlockListName: atp_svr.Name}, nil
		}
		if strings.EqualFold(dnsHost, strings.TrimSpace(atp_svr.Hardcore)) {
			return types.AntiTrackerMetadata{Enabled: true, Hardcore: true, AntiTrackerBlockListName: atp_svr.Name}, nil
		}
	}

	// Check AntiTracker values
	if strings.EqualFold(dnsHost, strings.TrimSpace(servers.Config.Antitracker.Default.IP)) {
		return types.AntiTrackerMetadata{Enabled: true, Hardcore: false}, nil
	}
	if strings.EqualFold(dnsHost, strings.TrimSpace(servers.Config.Antitracker.Hardcore.IP)) {
		return types.AntiTrackerMetadata{Enabled: true, Hardcore: true}, nil
	}

	return types.AntiTrackerMetadata{}, nil
}
