package ivpnclient

//
// Command Base
//

// CommandBase is a base object for communication with daemon.
// Contains fields required for all requests\responses.
type CommandBase struct {
	// this field represents command type
	Command string
	// Uses for separate request\response sessions.
	// Response messages must have same Index as request
	Idx uint32
}

func (c *CommandBase) Init(name string, idx uint32) {
	c.Command = name
	c.Idx = idx
}

func (c *CommandBase) Index() uint32 {
	return c.Idx
}

func (c *CommandBase) Name() string {
	return c.Command
}

// TODO: refactoring needed. This method should not be part of CommandBase
func (cb *CommandBase) LogExtraInfo() string {
	return ""
}

//
// Request base
//

// IRequestBase is an interface for requests to a daemon. Contains method Init to initialize all required fields of a request.
type IRequestBase interface {
	InitRequest(name string, idx uint32, protocolSecret string)
}

// RequestBase is a base object for requests to a daemon. Contains fields required for all requests.
type RequestBase struct {
	CommandBase
	ProtocolSecret string
}

func (rb *RequestBase) InitRequest(name string, idx uint32, protocolSecret string) {
	rb.CommandBase.Init(name, idx)
	rb.ProtocolSecret = protocolSecret
}

//
// Errors
//

type ErrorType int

const (
	ErrorUnknown                   ErrorType = iota
	ErrorParanoidModePasswordError ErrorType = iota
)

// ErrorResp response of error
type ErrorResp struct {
	CommandBase
	ErrorMessage string
	ErrorTitle   string
	ErrorType    ErrorType
}

func (e ErrorResp) Error() string {
	return e.ErrorMessage
}

// ErrorRespDelayed - error info which had happened in the past
type ErrorRespDelayed struct {
	ErrorResp
}

//
// Requests
//

// EmptyResp empty response on request
type EmptyResp struct {
	CommandBase
}

type ClientTypeEnum int

const (
	ClientUi         ClientTypeEnum = iota // 0
	ClientCli        ClientTypeEnum = iota // 1
	ClientPortmaster ClientTypeEnum = iota // 2
	ClientOthers     ClientTypeEnum = iota // 3
)

// Hello request to a daemon
// Have to be first request to a daemon for each client.
type Hello struct {
	RequestBase

	// connected client type
	ClientType ClientTypeEnum
	// connected client version
	Version string `json:",omitempty"`

	Secret uint64 `json:",omitempty"`

	// when 'true' - send HelloResp to all connected clients
	SendResponseToAllClients bool `json:",omitempty"`

	// GetServersList == true - client requests to send back info about all servers
	GetServersList bool `json:",omitempty"`

	// GetStatus == true - client requests current status (Vpn connection, Firewall... etc.)
	GetStatus bool `json:",omitempty"`

	// GetSplitTunnelStatus == true - client requests configuration of SplitTunnelling
	GetSplitTunnelStatus bool `json:",omitempty"`

	// GetWiFiCurrentState == true - client requests info about current WiFi
	GetWiFiCurrentState bool `json:",omitempty"`
}
