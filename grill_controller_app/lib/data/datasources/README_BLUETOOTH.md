# Bluetooth Service

## Overview

The `BluetoothService` handles Bluetooth Low Energy (BLE) communication with grill devices during the initial pairing process. It provides device discovery, connection management, and WiFi credential transmission.

## Requirements

- **1.2**: Bluetooth connection establishment
- **1.3**: WiFi credential transmission via Bluetooth
- **9.1**: Bluetooth communication protocol

## Features

### Device Discovery
- Scans for devices advertising the grill service UUID
- Returns a stream of discovered devices
- Configurable scan timeout (default: 10 seconds)
- Filters devices by service UUID to find compatible grill controllers

### Connection Management
- Establishes BLE connection with target device
- Monitors connection state for disconnections
- Automatic cleanup on disconnection
- Connection timeout protection (15 seconds)

### WiFi Credential Transmission
- Sends SSID and password to device via BLE characteristic
- JSON-encoded credential format
- Verified write operation (waits for acknowledgment)

### Error Handling
- `BluetoothException` for all Bluetooth-related errors
- Graceful handling of:
  - Bluetooth not supported
  - Bluetooth not enabled
  - Device not found
  - Connection failures
  - Credential transmission failures

## Usage

### Basic Discovery and Connection

```dart
final bluetoothService = BluetoothService();

// Discover devices
final stream = bluetoothService.discoverDevices(
  timeout: Duration(seconds: 10),
);

await for (final devices in stream) {
  print('Found ${devices.length} devices');
  
  if (devices.isNotEmpty) {
    final device = devices.first;
    
    // Connect to device
    await bluetoothService.connectDevice(device.id);
    
    // Send WiFi credentials
    await bluetoothService.sendWifiCredentials(
      device.id,
      'MyWiFiNetwork',
      'MyPassword123',
    );
    
    // Disconnect when done
    await bluetoothService.disconnect(device.id);
  }
}

// Clean up
await bluetoothService.dispose();
```

### Error Handling

```dart
try {
  await bluetoothService.connectDevice(deviceId);
} on BluetoothException catch (e) {
  print('Connection failed: ${e.message}');
  // Handle error (show user message, retry, etc.)
}
```

### Check Connection Status

```dart
if (bluetoothService.isConnected(deviceId)) {
  print('Device is connected');
}
```

## BLE Protocol

### Service UUID
- **Grill Service**: `0000fff0-0000-1000-8000-00805f9b34fb`

### Characteristics
- **WiFi Credentials**: `0000fff1-0000-1000-8000-00805f9b34fb`
  - Write characteristic for sending WiFi credentials
  - Format: JSON `{"ssid": "...", "password": "..."}`
  - UTF-8 encoded

- **Device Info**: `0000fff2-0000-1000-8000-00805f9b34fb`
  - Reserved for future use (device type detection, status)

## Platform Requirements

### Android
- Minimum SDK: 26 (Android 8.0)
- Required permissions in `AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.BLUETOOTH" />
  <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
  <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  ```

### iOS
- Minimum version: iOS 12.0
- Required keys in `Info.plist`:
  ```xml
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>This app needs Bluetooth to connect to your grill device</string>
  <key>NSBluetoothPeripheralUsageDescription</key>
  <string>This app needs Bluetooth to connect to your grill device</string>
  ```

### Windows
- Minimum version: Windows 10 build 17763
- Bluetooth support via Windows Runtime APIs

## Testing

The service includes comprehensive unit tests covering:
- Device discovery (with and without Bluetooth support)
- Connection management
- WiFi credential transmission
- Error handling
- Resource cleanup

Run tests:
```bash
flutter test test/data/datasources/bluetooth_service_test.dart
```

## Implementation Notes

1. **Connection Lifecycle**: The service maintains a map of connected devices and their connection subscriptions for proper cleanup.

2. **Automatic Disconnection Handling**: Connection state is monitored, and resources are automatically cleaned up when a device disconnects.

3. **Thread Safety**: The service uses async/await patterns to ensure thread-safe operations.

4. **Memory Management**: The `dispose()` method ensures all connections are closed and resources are freed.

5. **UUID Matching**: UUIDs are compared case-insensitively to handle different UUID formats from various devices.

## Future Enhancements

- Device type detection via device info characteristic
- Read device status during pairing
- Support for multiple simultaneous connections
- Connection retry with exponential backoff
- Signal strength (RSSI) monitoring
