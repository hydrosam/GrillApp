# Automatic Reconnection Logic

## Overview

The `IKamandHttpService` implements automatic reconnection logic with exponential backoff to handle device connection losses gracefully.

## Requirements

- **9.4**: When a device connection is lost, the app shall attempt to reconnect automatically
- **9.5**: When reconnection fails after 3 attempts, the app shall notify the user

## Implementation

### Exponential Backoff

The reconnection logic uses exponential backoff with the following delays:
- **Attempt 1**: 1 second delay
- **Attempt 2**: 2 seconds delay
- **Attempt 3**: 4 seconds delay

After 3 failed attempts, the reconnection process stops and emits a failure event.

### Reconnection Events

The service provides a stream of `ReconnectionEvent` objects that can be monitored to track reconnection progress:

```dart
service.reconnectionEvents.listen((event) {
  switch (event.status) {
    case ReconnectionStatus.attempting:
      print('Attempting reconnection: ${event.message}');
      break;
    case ReconnectionStatus.success:
      print('Reconnection successful!');
      break;
    case ReconnectionStatus.failed:
      print('Reconnection failed after 3 attempts');
      // Notify user
      break;
  }
});
```

### Automatic Triggering

Reconnection is automatically triggered when:
1. Status polling encounters a network error
2. A device request fails

### Manual Control

You can also manually control reconnection:

```dart
// Manually trigger reconnection
await service.attemptReconnection(deviceIp);

// Cancel ongoing reconnection attempts
service.cancelReconnection(deviceIp);
```

### Polling Integration

When status polling is started, the reconnection attempt count is automatically reset. If reconnection succeeds, polling is automatically restarted.

## Usage Example

```dart
final service = IKamandHttpService();

// Listen for reconnection events
service.reconnectionEvents.listen((event) {
  if (event.status == ReconnectionStatus.failed) {
    // Show user notification
    showNotification('Device connection lost. Please check your network.');
  }
});

// Start polling (reconnection happens automatically on errors)
final stream = service.startStatusPolling('192.168.1.100');
stream.listen(
  (status) {
    // Handle status updates
  },
  onError: (error) {
    // Error is logged, reconnection is triggered automatically
  },
);
```

## Testing

The reconnection logic is thoroughly tested in `ikamand_http_service_test.dart`:
- Exponential backoff timing
- Success after retry
- Failure after 3 attempts
- Cancellation
- Integration with status polling
- Event emission

## Notes

- The reconnection attempt count is reset after a successful reconnection
- Starting new polling resets the reconnection attempt count
- The service properly handles cleanup when disposed, preventing memory leaks
- All reconnection events are checked against stream controller state to prevent errors when the service is disposed
