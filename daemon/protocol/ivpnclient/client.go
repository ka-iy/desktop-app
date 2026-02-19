package ivpnclient

import (
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/crypto/pbkdf2"
)

// ClientInfo contains information about client, which will be sent to a daemon in Hello request right after connection.
type ClientInfo struct {
	Type    ClientTypeEnum
	Name    string
	Version string
}

type OnMessageEventHandler func(messageName string, messageData string)
type ParanoidModeSecretRequestFunc func() (secret string, isPlainText bool, err error)

// Client is a main object for communication with IVPN daemon.
type Client struct {
	_locker     sync.RWMutex
	_port       int
	_secret     uint64
	_clientInfo ClientInfo

	_paranoidModeSecret            string
	_paranoidModeSecretRequestFunc ParanoidModeSecretRequestFunc

	_conn   *Connection   // connection to a daemon
	_msgIdx atomic.Uint32 // last used message index, starts with 1

	// Custom handlers for specific messages from a daemon.
	// key - message name, value - handler for this message
	_msgEventHandlers map[string]OnMessageEventHandler
	_msgAwaiters      map[*responseAwaiter]struct{} // list of awaiters for responses from a daemon
	_msgLocker        sync.RWMutex                  // locker for _msgAwaiters and _msgEventHandlers

	_defaultTimeout time.Duration // default timeout for waiting for response from a daemon
	_logger         Logger
}

// NewClientAsRoot creates a new client for communication with IVPN daemon.
// Note: It is required to have root privileges to be able to read paranoid mode secret from a file.
func NewClientAsRoot(
	portInfoFile string,
	paranoidModeSecretFile string,
	logger Logger,
	responseDefaultTimeout time.Duration,
	clientInfo ClientInfo) (*Client, error) {

	// read connection info to be able to connect to a daemon
	port, secret, err := readDaemonPort(portInfoFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read daemon connection info: %w", err)
	}
	// create function to read paranoid mode secret directly from a file when it is required
	paranoidModeRequestFunc := func() (string, bool, error) {
		secret, err := readParanoidModeSecret(paranoidModeSecretFile)
		if err != nil {
			return "", false, fmt.Errorf("failed to read paranoid mode secret: %w", err)
		}
		return secret, false, nil
	}
	// create client
	return NewClient(port, secret, paranoidModeRequestFunc, logger, responseDefaultTimeout, clientInfo)
}

// NewClient creates a new client for communication with IVPN daemon.
func NewClient(
	port int,
	secret uint64,
	paranoidModeSecretRequestFunc ParanoidModeSecretRequestFunc,
	logger Logger,
	responseDefaultTimeout time.Duration,
	clientInfo ClientInfo) (*Client, error) {

	// ensure logger is not nil
	if logger == nil {
		logger = noopLogger{}
	}

	if clientInfo.Version == "" {
		clientInfo.Version = "unknown"
	}
	if clientInfo.Name == "" {
		clientInfo.Name = "unknown"
	}

	// create client
	return &Client{
		_port:                          port,
		_secret:                        secret,
		_logger:                        logger,
		_paranoidModeSecretRequestFunc: paranoidModeSecretRequestFunc,
		_clientInfo:                    clientInfo,
		_defaultTimeout:                responseDefaultTimeout,
		_msgAwaiters:                   make(map[*responseAwaiter]struct{}),
		_msgEventHandlers:              make(map[string]OnMessageEventHandler),
	}, nil
}

// SetParanoidModeSecret sets secret for paranoid mode. This secret will be added to all requests to a daemon and allows to avoid asking user for password when it is required.
func (c *Client) SetParanoidModeSecret(secret string) {
	c._locker.Lock()
	defer c._locker.Unlock()
	c._paranoidModeSecret = secret
}

func (c *Client) SetParanoidModeSecretPlainText(password string) {
	if len(password) <= 0 {
		return
	}
	hash := pbkdf2.Key([]byte(password), []byte(""), 4096, 64, sha256.New)
	c.SetParanoidModeSecret(base64.StdEncoding.EncodeToString(hash))
}

// Disconnect disconnects from a daemon and stops all routines related to connection with a daemon.
func (c *Client) Disconnect() {
	c._locker.Lock()
	defer c._locker.Unlock()

	if c._conn != nil {
		c._conn.Disconnect()
		c._conn = nil
	}
}

// Connect establishes connection to a daemon and starts routine to receive messages from a daemon.
// Note: Hello request must be first to start communication with a daemon
func (c *Client) Connect() error {
	err := func() error {
		c._locker.Lock()
		defer c._locker.Unlock()

		if c._conn != nil {
			return fmt.Errorf("already connected")
		}

		var err error
		c._conn, err = NewConnection(c._logger)
		if err != nil {
			return fmt.Errorf("failed to create connection to IVPN daemon: %w", err)
		}
		return nil
	}()
	if err != nil {
		return err
	}

	// establish connection to a daemon
	if err := c._conn.Connect(uint(c._port)); err != nil {
		c.Disconnect()
		return fmt.Errorf("failed to connect to IVPN daemon: %w", err)
	}

	// start handler for received messages from a daemon
	go c.recvMessagesHandler()

	return nil
}

// SetMessageEventHandler sets handler for specific message from a daemon.
// If handler is nil - removes handler for this message.
// If messageName is empty string - handler will be called for all messages from a daemon.
func (c *Client) SetMessageEventHandler(messageName string, handler OnMessageEventHandler) {
	c._msgLocker.Lock()
	defer c._msgLocker.Unlock()
	if handler == nil {
		delete(c._msgEventHandlers, messageName)
		return
	}
	c._msgEventHandlers[messageName] = handler
}

// SendRecv sends request to a daemon and waits for response with default timeout.
func (c *Client) SendRecv(request IRequestBase, response interface{}) error {
	ignoreResponseIndex := false
	return c.sendRecv(request, ignoreResponseIndex, c._defaultTimeout, response)
}

// SendRecvTimeOut sends request to a daemon and waits for response with specified timeout.
func (c *Client) SendRecvTimeOut(request IRequestBase, response interface{}, timeout time.Duration) error {
	ignoreResponseIndex := false
	return c.sendRecv(request, ignoreResponseIndex, timeout, response)
}

// SendRecvAny sends request to a daemon and waits for any response with default timeout.
// Note: This function ignores response index and waits for any of responses with names from waitingObjects list
func (c *Client) SendRecvAny(request IRequestBase, waitingObjects ...interface{}) error {
	ignoreResponseIndex := true
	return c.sendRecv(request, ignoreResponseIndex, c._defaultTimeout, waitingObjects...)
}

// SendRecvAnyEx sends request to a daemon and waits for any response with specified timeout.
// If ignoreResponseIndex is true - this function ignores response index and waits for any of responses with names from waitingObjects list
func (c *Client) SendRecvAnyEx(request IRequestBase, ignoreResponseIndex bool, waitingObjects ...interface{}) error {
	return c.sendRecv(request, ignoreResponseIndex, c._defaultTimeout, waitingObjects...)
}

func (c *Client) InitHelloRequest() Hello {
	version := strings.ReplaceAll(strings.TrimSpace(c._clientInfo.Version), ":", " ") + ":" + strings.ReplaceAll(strings.TrimSpace(c._clientInfo.Name), ":", " ")
	return Hello{
		Secret:     c._secret,
		ClientType: c._clientInfo.Type,
		GetStatus:  true,
		Version:    version,
	}
}

func (c *Client) getNextMsgIdx() uint32 {
	c._msgIdx.Add(1)
	c._msgIdx.CompareAndSwap(0, 1) // handles overflow wrap-around
	return c._msgIdx.Load()
}

func (c *Client) send(cmd IRequestBase, idx uint32) error {
	if cmd == nil {
		return fmt.Errorf("command is nil")
	}

	c._locker.RLock()
	defer c._locker.RUnlock()

	if c._conn == nil {
		return fmt.Errorf("not connected to IVPN daemon")
	}

	// initialize command with name, index and protocol secret
	cmd.InitRequest(GetTypeName(cmd), idx, c._paranoidModeSecret)

	return c._conn.Send(cmd)
}

func (c *Client) sendRecv(request IRequestBase, ignoreResponseIndex bool, timeout time.Duration, waitingObjects ...interface{}) error {
	doJob := func() error {
		var waiter *responseAwaiter
		msgIdx := c.getNextMsgIdx()

		// thread-safe receiver registration
		func() {
			c._msgLocker.Lock()
			defer c._msgLocker.Unlock()
			waiter = createAwaiter(msgIdx, ignoreResponseIndex, waitingObjects...)
			c._msgAwaiters[waiter] = struct{}{}
		}()
		// do not forget to remove receiver
		defer func() {
			c._msgLocker.Lock()
			defer c._msgLocker.Unlock()
			delete(c._msgAwaiters, waiter)
		}()
		// send request
		if err := c.send(request, msgIdx); err != nil {
			return err
		}
		// waiting for response
		if err := waiter.wait(timeout); err != nil {
			return err
		}
		return nil
	}

	err := doJob()
	if errResp, ok := err.(ErrorResp); ok && errResp.ErrorType == ErrorParanoidModePasswordError {
		// Paranoid mode password error
		if c._paranoidModeSecretRequestFunc != nil {
			// request user for Password
			pass := ""
			isPlainText := false
			pass, isPlainText, err = c._paranoidModeSecretRequestFunc()
			if err != nil {
				return err
			}
			if isPlainText {
				c.SetParanoidModeSecretPlainText(pass)
			} else {
				c.SetParanoidModeSecret(pass)
			}

			err = doJob()
		}
	}

	return err
}

func (c *Client) recvMessagesHandler() {
	defer func() {
		c._locker.Lock()
		defer c._locker.Unlock()
		if c._conn != nil {
			c._conn.Disconnect()
			c._conn = nil
		}
		c._logger.Info("Receiver routine stopped")
	}()

	for msg := range c._conn.ReceivedMessages() {
		messageData := []byte(msg)

		cmd, err := DeserializeCommandBase(messageData)
		if err != nil {
			c._logger.Error("Failed to parse response:", err)
			return
		}

		func() {
			c._msgLocker.RLock()
			defer c._msgLocker.RUnlock()

			// check if received message is expected for any of waiters and push response to it
			for waiter := range c._msgAwaiters {
				if waiter.isExpectedResponse(cmd) {
					waiter.pushResponse(messageData)
					break
				}
			}

			// check if we have handler for this message
			// "" handler with empty message name is called for all messages
			for handlerMessageName, handler := range c._msgEventHandlers {
				if handlerMessageName == "" || handlerMessageName == cmd.Command {
					handler(cmd.Command, msg)
					if handlerMessageName != "" {
						break
					}
				}
			}
		}()
	}
}
