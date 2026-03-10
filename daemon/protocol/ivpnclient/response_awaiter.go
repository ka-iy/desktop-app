package ivpnclient

import (
	"encoding/json"
	"fmt"
	"time"
)

// ResponseTimeout error
type ResponseTimeout struct {
}

func (e ResponseTimeout) Error() string {
	return "response timeout"
}

func createAwaiter(waitingIdx uint32, ignoreResponseIndex bool, waitingObjectsList ...interface{}) *responseAwaiter {
	waitingObjects := make(map[string]interface{})

	for _, wo := range waitingObjectsList {
		if wo == nil {
			continue
		}
		waitingType := GetTypeName(wo)
		waitingObjects[waitingType] = wo
	}

	receiver := &responseAwaiter{
		_ignoreResponseIndex: ignoreResponseIndex,
		_waitingIdx:          waitingIdx,
		_waitingObjects:      waitingObjects,
		_channel:             make(chan []byte, 1)}

	return receiver
}

type responseAwaiter struct {
	_ignoreResponseIndex bool
	_waitingIdx          uint32
	_waitingObjects      map[string]interface{}
	_channel             chan []byte
	_receivedData        []byte
	_receivedCmdBase     CommandBase
}

func (r *responseAwaiter) isExpectedResponse(cmd CommandBase) bool {
	// response is acceptable when:
	// - received expected responseIndex
	// - received error (types.ErrorResp) with correspond responseIndex (even if we are not waiting for response index)
	// - we are not waiting for response index but received one of responses from _waitingObjects
	// - when we do not care about responseIndex and response objects

	if r._ignoreResponseIndex && len(r._waitingObjects) == 0 {
		return true // - when we do not care about responseIndex and response objects
	}
	if r._ignoreResponseIndex {
		if cmd.Command == GetTypeName(ErrorResp{}) {
			// - received error (types.ErrorResp) with correspond responseIndex (even if we are not waiting for response index)
			return true
		}
	}

	if !r._ignoreResponseIndex {
		if r._waitingIdx == cmd.Idx {
			return true // - received expected responseIndex
		}
	} else {
		if len(r._waitingObjects) > 0 {
			if _, ok := r._waitingObjects[cmd.Command]; ok {
				return true // - we are not waiting for response index but received one of responses from _waitingObjects
			}
		}
	}

	return false
}

func (r *responseAwaiter) pushResponse(responseData []byte) error {
	select {
	case r._channel <- responseData:
	default:
		return fmt.Errorf("receiver channel is full")
	}
	return nil
}

func (r *responseAwaiter) wait(timeout time.Duration) (err error) {
	select {
	case r._receivedData = <-r._channel:
		// check type of response
		if err := deserialize(r._receivedData, &r._receivedCmdBase); err != nil {
			return fmt.Errorf("response deserialization failed: %w", err)
		}

		if len(r._waitingObjects) > 0 {
			if wo, ok := r._waitingObjects[r._receivedCmdBase.Command]; ok {
				// deserialize response into expected object type
				if err := deserialize(r._receivedData, wo); err != nil {
					return fmt.Errorf("response deserialization failed: %w", err)
				}
			} else {
				// check is it Error object
				var errObj ErrorResp
				if r._receivedCmdBase.Command == GetTypeName(errObj) {
					if err := deserialize(r._receivedData, &errObj); err != nil {
						return fmt.Errorf("response deserialization failed: %w", err)
					}
					return errObj
				}
				return fmt.Errorf("received unexpected data (type:%s)", r._receivedCmdBase.Command)
			}
		}
		return nil

	case <-time.After(timeout):
		return ResponseTimeout{}
	}
}

func deserialize(messageData []byte, obj interface{}) error {
	if err := json.Unmarshal(messageData, obj); err != nil {
		return fmt.Errorf("failed to parse command data: %w", err)
	}
	return nil
}
