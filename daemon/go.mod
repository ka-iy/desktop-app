module github.com/ivpn/desktop-app/daemon

go 1.24.0

toolchain go1.24.7

require (
	github.com/fsnotify/fsnotify v1.9.0
	github.com/google/uuid v1.6.0
	github.com/ivpn/desktop-app/daemon/protocol/ivpnclient v0.0.0
	github.com/mdlayher/wifi v0.5.1-0.20250704183335-1b2199ae492f
	github.com/parsiya/golnk v0.0.0-20221103095132-740a4c27c4ff
	github.com/shirou/gopsutil/v4 v4.26.5
	github.com/stretchr/testify v1.11.1
	golang.org/x/net v0.49.0
	golang.org/x/sync v0.12.0
	golang.org/x/sys v0.41.0
	golang.zx2c4.com/wireguard/wgctrl v0.0.0-20241231184526-a9ab2273dd10
	golang.zx2c4.com/wireguard/windows v0.5.3
)

require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/ebitengine/purego v0.10.0 // indirect
	github.com/go-ole/go-ole v1.2.6 // indirect
	github.com/google/go-cmp v0.7.0 // indirect
	github.com/josharian/native v1.1.0 // indirect
	github.com/lufia/plan9stats v0.0.0-20211012122336-39d0f177ccd0 // indirect
	github.com/mattn/go-runewidth v0.0.16 // indirect
	github.com/mdlayher/genetlink v1.3.2 // indirect
	github.com/mdlayher/netlink v1.7.2 // indirect
	github.com/mdlayher/socket v0.5.1 // indirect
	github.com/olekukonko/tablewriter v0.0.5 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/power-devops/perfstat v0.0.0-20240221224432-82ca36839d55 // indirect
	github.com/rivo/uniseg v0.4.7 // indirect
	github.com/tklauser/go-sysconf v0.3.16 // indirect
	github.com/tklauser/numcpus v0.11.0 // indirect
	github.com/yusufpapurcu/wmi v1.2.4 // indirect
	golang.org/x/crypto v0.48.0 // indirect
	golang.zx2c4.com/wireguard v0.0.0-20231211153847-12269c276173 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace github.com/ivpn/desktop-app/daemon/protocol/ivpnclient => ./protocol/ivpnclient
