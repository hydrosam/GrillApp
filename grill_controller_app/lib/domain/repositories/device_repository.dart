import '../entities/grill_device.dart';

/// Repository for device communication and management
/// 
/// Handles device discovery, connection (Bluetooth and WiFi),
/// and command transmission to grill devices.
abstract class DeviceRepository {
  /// Watch real-time updates for a specific device
  /// 
  /// Returns a stream that emits device state changes including
  /// connection status, probe states, and fan status.
  /// 
  /// Requirements: 2.2, 9.2
  Stream<GrillDevice> watchDevice(String deviceId);

  /// Discover available devices via Bluetooth
  /// 
  /// Scans for devices in pairing mode and returns a list
  /// of discovered devices.
  /// 
  /// Requirements: 1.1, 1.2, 9.1
  Future<List<GrillDevice>> discoverDevices();

  /// Connect to a device via Bluetooth
  /// 
  /// Establishes Bluetooth connection with the specified device.
  /// This is the first step in the pairing process.
  /// 
  /// Requirements: 1.2, 9.1
  Future<void> connectBluetooth(String deviceId);

  /// Send WiFi credentials to device via Bluetooth
  /// 
  /// Transmits the WiFi network SSID and password to the device
  /// so it can connect to the local network.
  /// 
  /// Requirements: 1.3
  Future<void> sendWifiCredentials(
    String deviceId,
    String ssid,
    String password,
  );

  /// Set fan speed on the device
  /// 
  /// Sends a fan speed command to the device. Speed should be
  /// a percentage value between 0 and 100.
  /// 
  /// Requirements: 3.6, 9.2, 9.3
  Future<void> setFanSpeed(String deviceId, int speed);

  /// Set target temperature on the device
  /// 
  /// Sends a target temperature command to the device.
  /// Temperature should be in Fahrenheit.
  /// 
  /// Requirements: 3.1, 9.2, 9.3
  Future<void> setTargetTemperature(String deviceId, double temperature);

  /// Disconnect from a device
  /// 
  /// Closes the connection to the device (Bluetooth or WiFi).
  /// 
  /// Requirements: 9.2
  Future<void> disconnect(String deviceId);

  /// Get device type and capabilities
  /// 
  /// Detects the device type during initial connection and
  /// returns device-specific capabilities.
  /// 
  /// Requirements: 9.6
  Future<DeviceType> detectDeviceType(String deviceId);
}
