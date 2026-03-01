# iKamand HTTP Service

## Overview

The `IKamandHttpService` provides HTTP-based communication with iKamand grill controller devices over WiFi. This service is used after the initial Bluetooth pairing to monitor device status and send control commands.

## Requirements

- **1.5**: WiFi-based communication after Bluetooth pairing
- **9.2**: HTTP protocol for ongoing device control
- **9.3**: iKamand protocol implementation

## Architecture

### Models

#### IKamandStatus
Represents the device status response from the iKamand API.

**Fields:**
- `grillTemp` (double): Grill probe temperature in Fahrenheit
- `food1Temp` (double?): Food probe 1 temperature (null if disconnected)
- `food2Temp` (double?): Food probe 2 temperature (null if disconnected)
- `food3Temp` (double?): Food probe 3 temperature (null if disconnected)
- `fanSpeed` (int): Current fan speed (0-100%)
- `targetTemp` (double): Target grill temperature in Fahrenheit

**JSON Format:**
```json
{
  "grill_temp": 250.5,
  "food1_temp": 165.0,
  "food2_temp": null,
  "food3_temp": null,
  "fan_speed": 45,
  "target_temp": 275.0
}
```

#### IKamandCommand
Represents a command to send to the iKamand device.

**Fields:**
- `fanSpeed` (int?): Fan speed to set (0-100%)
- `targetTemp` (double?): Target temperature to set (32-1000°F)

**Factory Constructors:**
- `IKamandCommand.setFanSpeed(int speed)`: Set only fan speed
- `IKamandCommand.setTargetTemp(double temp)`: Set only target temperature
- `IKamandCommand.setBoth(int speed, double temp)`: Set both values

**JSON Format:**
```json
{
  "fan_speed": 50,
  "target_temp": 275.0
}
```

### Service

#### IKamandHttpService

**Key Methods:**

##### getStatus(String deviceIp)
Fetches the current device status via HTTP GET.

```dart
final status = await service.getStatus('192.168.1.100');
print('Grill temp: ${status.grillTemp}°F');
```

**Endpoint:** `GET http://{deviceIp}/status`

**Timeout:** 5 seconds

**Throws:** `IKamandHttpException` on error

##### sendCommand(String deviceIp, IKamandCommand command)
Sends a command to the device via HTTP POST.

```dart
final command = IKamandCommand.setFanSpeed(50);
await service.sendCommand('192.168.1.100', command);
```

**Endpoint:** `POST http://{deviceIp}/command`

**Timeout:** 5 seconds

**Throws:** `IKamandHttpException` on error

##### startStatusPolling(String deviceIp, {Duration interval})
Starts polling the device status at regular intervals.

```dart
final stream = service.startStatusPolling(
  '192.168.1.100',
  interval: Duration(seconds: 5),
);

stream.listen((status) {
  print('Grill temp: ${status.grillTemp}°F');
});
```

**Default Interval:** 5 seconds (per Requirement 2.6)

**Returns:** `Stream<IKamandStatus>`

##### stopStatusPolling(String deviceIp)
Stops polling for a specific device.

```dart
service.stopStatusPolling('192.168.1.100');
```

##### testConnection(String deviceIp)
Tests if a device is reachable and responding.

```dart
final isReachable = await service.testConnection('192.168.1.100');
if (isReachable) {
  print('Device is online');
}
```

**Returns:** `bool` - true if device responds, false otherwise

##### statusToTemperatureReadings(IKamandStatus status, String deviceId)
Converts a status response to a list of temperature readings.

```dart
final readings = service.statusToTemperatureReadings(status, 'device1');
// Returns TemperatureReading objects for all active probes
```

##### statusToProbes(IKamandStatus status, String deviceId)
Converts a status response to a list of probe entities.

```dart
final probes = service.statusToProbes(status, 'device1');
// Returns Probe objects with active/inactive status
```

## Usage Example

```dart
// Create service
final service = IKamandHttpService();

// Test connection
final isOnline = await service.testConnection('192.168.1.100');
if (!isOnline) {
  print('Device not reachable');
  return;
}

// Start polling
final stream = service.startStatusPolling('192.168.1.100');
stream.listen((status) {
  print('Grill: ${status.grillTemp}°F');
  print('Target: ${status.targetTemp}°F');
  print('Fan: ${status.fanSpeed}%');
});

// Send command
final command = IKamandCommand.setTargetTemp(275.0);
await service.sendCommand('192.168.1.100', command);

// Stop polling when done
service.stopStatusPolling('192.168.1.100');

// Clean up
service.dispose();
```

## Error Handling

All HTTP operations can throw `IKamandHttpException` with descriptive error messages:

- **Network errors**: Connection refused, timeout, etc.
- **HTTP errors**: 404, 500, etc.
- **Parse errors**: Invalid JSON response

```dart
try {
  final status = await service.getStatus('192.168.1.100');
} on IKamandHttpException catch (e) {
  print('Error: ${e.message}');
}
```

## Protocol Details

### Endpoints

- **Status**: `GET http://{deviceIp}/status`
  - Returns current device status
  - Response: JSON with temperature readings, fan speed, target temp

- **Command**: `POST http://{deviceIp}/command`
  - Sends control command to device
  - Request body: JSON with fan_speed and/or target_temp
  - Response: 200 OK or 204 No Content

### Timeouts

All HTTP requests have a 5-second timeout to prevent hanging on network issues.

### Polling

Status polling uses a timer to fetch status at regular intervals. The default interval is 5 seconds to meet Requirement 2.6 (refresh at least once every 5 seconds).

## Testing

Comprehensive unit tests are provided in `test/data/datasources/ikamand_http_service_test.dart`:

- Status fetching with various probe configurations
- Command sending with different command types
- Status polling with interval timing
- Error handling for network, HTTP, and parse errors
- Connection testing
- Model serialization/deserialization

Run tests:
```bash
flutter test test/data/datasources/ikamand_http_service_test.dart
flutter test test/data/models/ikamand_models_test.dart
```

## Integration with Repository

The `IKamandHttpService` is used by the `DeviceRepository` implementation to:

1. Test WiFi connectivity after Bluetooth pairing
2. Poll device status for real-time temperature updates
3. Send fan speed and target temperature commands
4. Convert status responses to domain entities

See `DeviceRepository` implementation for integration details.
