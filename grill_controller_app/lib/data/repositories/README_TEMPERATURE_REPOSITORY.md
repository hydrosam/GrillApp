# TemperatureRepository Implementation

## Overview

The `TemperatureRepositoryImpl` provides concrete implementation of the `TemperatureRepository` interface, handling real-time temperature streaming from devices and persistence of temperature readings.

## Key Features

### 1. Temperature Streaming (Requirements 2.2, 2.6)
- Streams temperature readings from devices via `IKamandHttpService`
- Polls device status every 5 seconds (configurable)
- Converts device status to temperature readings for all active probes
- Broadcasts readings to multiple listeners via stream controllers

### 2. Automatic Persistence (Requirements 2.3, 10.4)
- Automatically saves temperature readings during active cook sessions
- Uses session tracking to associate readings with cook sessions
- Handles save errors gracefully without interrupting the stream

### 3. Historical Data Queries (Requirements 2.3, 2.4)
- Retrieves temperature history by device and time range
- Filters readings by device ID from probe IDs
- Supports session-specific history queries
- Efficient SQLite queries via `TemperatureDatabaseHelper`

### 4. Data Management (Requirements 10.1)
- Deletes old readings to manage storage space
- Gets latest reading for specific probes
- Supports cleanup of historical data

## Architecture

```
TemperatureRepositoryImpl
├── IKamandHttpService (temperature streaming)
│   └── Polls device status every 5 seconds
│   └── Converts status to temperature readings
├── TemperatureDatabaseHelper (persistence)
│   └── SQLite storage with time-series indexes
│   └── Efficient queries for historical data
└── LocalStorageService (device lookup)
    └── Gets device IP for streaming
```

## Usage Example

```dart
// Create repository
final repository = TemperatureRepositoryImpl(
  databaseHelper: TemperatureDatabaseHelper.instance,
  httpService: IKamandHttpService(),
);

// Start a cook session
repository.setActiveSession('device1', 'session1');

// Watch temperature updates
final stream = repository.watchTemperatures('device1');
stream.listen((reading) {
  print('${reading.type}: ${reading.temperature}°F');
});

// Get historical data
final history = await repository.getHistory(
  'device1',
  DateTime.now().subtract(Duration(hours: 2)),
  DateTime.now(),
);

// Clean up
repository.stopWatching('device1');
repository.dispose();
```

## Session Management

The repository tracks active sessions per device to enable automatic saving:

- `setActiveSession(deviceId, sessionId)` - Start tracking a session
- `getActiveSession(deviceId)` - Get current session ID
- `stopWatching(deviceId)` - Stop streaming and clear session

When a session is active, all temperature readings are automatically saved to the database with the session ID.

## Error Handling

- Database errors during auto-save are logged but don't interrupt streaming
- Missing devices return error in stream
- Devices without WiFi connection return error in stream
- All public methods throw exceptions with descriptive messages

## Testing

Comprehensive unit tests cover:
- ✅ Saving temperature readings
- ✅ Getting historical data with time range filtering
- ✅ Getting session-specific history
- ✅ Deleting old readings
- ✅ Getting latest readings
- ✅ Session management
- ✅ Error handling
- ✅ Resource cleanup

See `test/data/repositories/temperature_repository_impl_test.dart` for details.

## Requirements Validation

| Requirement | Implementation |
|-------------|----------------|
| 2.2 - Update display within 2 seconds | ✅ Streams readings every 5 seconds |
| 2.3 - Historical record with timestamps | ✅ SQLite storage with timestamps |
| 2.6 - Refresh at least every 5 seconds | ✅ 5-second polling interval |
| 10.1 - Store in local device storage | ✅ SQLite database |
| 10.4 - Persist at least once per minute | ✅ Auto-save on every reading |

## Future Enhancements

- Batch saving for improved performance
- Configurable polling intervals per device
- Support for multiple simultaneous sessions
- Offline queue for failed saves
- Data compression for long-term storage
