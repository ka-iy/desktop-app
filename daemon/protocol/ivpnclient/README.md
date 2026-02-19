# ivpnclient

Go client library for communicating with the [IVPN](https://ivpn.net) daemon
over its local IPC channel.

## Overview

The IVPN daemon exposes a JSON-over-TCP loopback interface for local
privileged clients — the desktop UI, the CLI tool, and third-party
integrations such as [Portmaster](https://safing.io/portmaster/).

This module provides:

- Type-safe request/response wrappers matching the daemon protocol.
- Transparent retry on Paranoid Mode password errors.
- Asynchronous push-notification (event) callbacks.
- Thread-safe connection management.

## Requirements

- Go 1.21 or later.
- IVPN daemon installed and running on the local machine.

## Usage

```go
import (
    "fmt"
    "log"
    "time"

    "github.com/ivpn/desktop-app/daemon/protocol/ivpnclient"
)

client, err := ivpnclient.NewClientAsRoot(
    portInfoFile,        // path to daemon port-info file
    paranoidModeFile,    // path to paranoid-mode secret file (pass "" to skip)
    nil,                 // Logger — nil discards all logs
    30*time.Second,      // default response timeout
    ivpnclient.ClientInfo{
        Type:    ivpnclient.ClientCli,
        Name:    "my-app",
        Version: "1.0.0",
    },
)
if err != nil {
    log.Fatal(err)
}
if err := client.Connect(); err != nil {
    log.Fatal(err)
}
defer client.Disconnect()

// The Hello request is required to be sent before any other request
hello := client.InitHelloRequest()
if err := client.SendRecv(&hello, nil); err != nil {
    log.Fatal(err)
}

// Subscribe to all daemon push events
client.SetMessageEventHandler("", func(name, data string) {
    fmt.Println(name, data)
})

// Erase custom DNS settings and disable AntiTracker
if err := client.SetManualDNS(ivpnclient.DnsSettings{}, ivpnclient.AntiTrackerMetadata{}); err != nil {
    log.Fatal(err)
}
```

## License

Copyright © 2026 IVPN Limited.  
GNU General Public License v3.0.
