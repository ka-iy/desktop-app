package ivpnclient

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"strings"
	"sync"
	"time"
)

const (
	writeTimeout       = 5 * time.Second
	recvChannelTimeout = 5 * time.Second
)

type Connection struct {
	_mu               sync.RWMutex
	_conn             net.Conn
	_recvMsgsChan     chan string // channel for received json messages from a daemon
	_logger           Logger
	_disconnectedChan chan struct{} // channel to signal that connection is closed
}

func NewConnection(logger Logger) (*Connection, error) {
	if logger == nil {
		logger = noopLogger{}
	}
	return &Connection{
		_logger:           logger,
		_recvMsgsChan:     make(chan string, 16),
		_disconnectedChan: make(chan struct{}),
	}, nil
}

// Connect is establishing connection to a daemon and starts receiver routine to receive messages from a daemon
func (c *Connection) Connect(port uint) (err error) {
	err = func() error {
		c._mu.Lock()
		defer c._mu.Unlock()

		if c._conn != nil {
			return fmt.Errorf("already connected")
		}

		dialer := net.Dialer{
			LocalAddr: &net.TCPAddr{IP: net.ParseIP("127.0.0.1")},
		}
		c._conn, err = dialer.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", port))
		if err != nil {
			return fmt.Errorf("failed to connect to IVPN daemon (does IVPN daemon/service running?): %w", err)
		}
		return nil
	}()

	if err != nil {
		return err
	}

	// start receiver
	go c.receiverRoutine()

	return nil
}

// Disconnect closes connection to a daemon and stops receiver routine
func (c *Connection) Disconnect() {
	c._mu.Lock()
	defer c._mu.Unlock()

	if c._conn != nil {
		c._conn.Close()
	}
}

// Disconnected returns channel to signal that connection is closed
func (c *Connection) Disconnected() <-chan struct{} {
	return c._disconnectedChan
}

// ReceivedMessages returns channel with received messages from a daemon
func (c *Connection) ReceivedMessages() <-chan string {
	return c._recvMsgsChan
}

// SendRequest serializes object to json and sends it to a daemon
func (c *Connection) Send(cmd interface{}) error {
	if cmd == nil {
		return fmt.Errorf("command is nil")
	}

	c._mu.RLock()
	defer c._mu.RUnlock()

	if c._conn == nil {
		return fmt.Errorf("connection is nil")
	}

	// serialize command to json
	bytesToSend, err := json.Marshal(cmd)
	if err != nil {
		return fmt.Errorf("failed to serialize command: %w", err)
	}
	if bytesToSend == nil {
		return fmt.Errorf("data is nil")
	}
	bytesToSend = append(bytesToSend, byte('\n'))

	// send data to a daemon
	_ = c._conn.SetWriteDeadline(time.Now().Add(writeTimeout))
	if _, err := c._conn.Write(bytesToSend); err != nil {
		return err
	}
	return nil
}

func (c *Connection) receiverRoutine() {
	defer func() {
		c._mu.Lock()

		c._conn.Close()
		c._conn = nil
		close(c._recvMsgsChan)
		close(c._disconnectedChan)

		c._mu.Unlock()

		c._logger.Info("Receiver stopped")
	}()

	c._logger.Info("Receiver started")

	c._mu.RLock()
	reader := bufio.NewReader(c._conn)
	c._mu.RUnlock()

	// run loop forever
	for {
		// will listen for message to process ending in newline (\n)
		message, err := reader.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				c._logger.Info("Daemon closed the connection")
				break
			}
			c._logger.Error("Error receiving data from daemon: ", err)
			break
		}

		// send received message to channel for processing
		select {
		case c._recvMsgsChan <- strings.TrimSpace(message):
		case <-time.After(recvChannelTimeout):
			c._logger.Error("Error processing received message from daemon: channel is blocked too long")
		}
	}
}
