import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/entities/grill_device.dart';
import '../../domain/entities/fan_status.dart';

/// Service for Bluetooth Low Energy communication with grill devices
/// 
/// Handles device discovery, connection, and credential transmission
/// during the initial pairing process.
/// 
/// Requirements: 1.2, 1.3, 9.1
class BluetoothService {
  // Service UUID for grill devices (example - should match actual device)
  static const String _grillServiceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  
  // Characteristic UUID for WiFi credential transmission
  static const String _wifiCredentialCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  
  // Characteristic UUID for device info/status
  static const String _deviceInfoCharUuid = '0000fff2-0000-1000-8000-00805f9b34fb';

  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  final StreamController<List<GrillDevice>> _discoveryController = 
      StreamController<List<GrillDevice>>.broadcast();

  /// Discover available Bluetooth devices in pairing mode
  /// 
  /// Scans for devices advertising the grill service UUID.
  /// Returns a stream of discovered devices.
  /// 
  /// Requirements: 1.1, 1.2, 9.1
  Stream<List<GrillDevice>> discoverDevices({Duration timeout = const Duration(seconds: 10)}) async* {
    final List<GrillDevice> discoveredDevices = [];
    
    try {
      // Check if Bluetooth is available and enabled
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        throw BluetoothException('Bluetooth is not supported on this device');
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        throw BluetoothException('Bluetooth is not enabled');
      }

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: [Guid(_grillServiceUuid)],
      );

      // Listen to scan results
      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        discoveredDevices.clear();
        
        for (final result in results) {
          final device = result.device;
          
          // Create GrillDevice from scan result
          final grillDevice = GrillDevice(
            id: device.remoteId.toString(),
            name: device.platformName.isNotEmpty 
                ? device.platformName 
                : 'Unknown Device',
            type: DeviceType.unknown, // Will be detected after connection
            status: ConnectionStatus.disconnected,
            probes: [], // Will be populated after connection
            fanStatus: FanStatus(
              speed: 0,
              isAutomatic: false,
              lastUpdate: DateTime.now(),
            ),
          );
          
          discoveredDevices.add(grillDevice);
        }
        
        _discoveryController.add(List.from(discoveredDevices));
      });

      // Wait for scan to complete
      await Future.delayed(timeout);
      await scanSubscription.cancel();
      await FlutterBluePlus.stopScan();

      yield discoveredDevices;
    } catch (e) {
      throw BluetoothException('Device discovery failed: $e');
    }
  }

  /// Connect to a device via Bluetooth
  /// 
  /// Establishes a Bluetooth connection with the specified device.
  /// 
  /// Requirements: 1.2, 9.1
  Future<void> connectDevice(String deviceId) async {
    try {
      // Find the device
      final devices = FlutterBluePlus.connectedDevices;
      BluetoothDevice? targetDevice;
      
      for (final device in devices) {
        if (device.remoteId.toString() == deviceId) {
          targetDevice = device;
          break;
        }
      }

      // If not already connected, scan for it
      if (targetDevice == null) {
        final scanResults = await FlutterBluePlus.scanResults.first;
        for (final result in scanResults) {
          if (result.device.remoteId.toString() == deviceId) {
            targetDevice = result.device;
            break;
          }
        }
      }

      if (targetDevice == null) {
        throw BluetoothException('Device not found: $deviceId');
      }

      // Connect to the device
      await targetDevice.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Store the connected device
      _connectedDevices[deviceId] = targetDevice;

      // Monitor connection state
      final connectionSubscription = targetDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection(deviceId);
        }
      });
      
      _connectionSubscriptions[deviceId] = connectionSubscription;

      // Discover services
      await targetDevice.discoverServices();
    } catch (e) {
      throw BluetoothException('Connection failed: $e');
    }
  }

  /// Send WiFi credentials to device via Bluetooth
  /// 
  /// Transmits SSID and password to the device so it can connect
  /// to the local WiFi network.
  /// 
  /// Requirements: 1.3
  Future<void> sendWifiCredentials(
    String deviceId,
    String ssid,
    String password,
  ) async {
    try {
      final device = _connectedDevices[deviceId];
      if (device == null) {
        throw BluetoothException('Device not connected: $deviceId');
      }

      // Find the WiFi credential characteristic
      final services = await device.discoverServices();
      BluetoothCharacteristic? wifiChar;

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == _grillServiceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == _wifiCredentialCharUuid.toLowerCase()) {
              wifiChar = char;
              break;
            }
          }
        }
      }

      if (wifiChar == null) {
        throw BluetoothException('WiFi credential characteristic not found');
      }

      // Prepare credentials as JSON
      final credentials = {
        'ssid': ssid,
        'password': password,
      };
      
      final credentialsJson = jsonEncode(credentials);
      final credentialsBytes = utf8.encode(credentialsJson);

      // Write credentials to characteristic
      await wifiChar.write(credentialsBytes, withoutResponse: false);
    } catch (e) {
      throw BluetoothException('Failed to send WiFi credentials: $e');
    }
  }

  /// Disconnect from a device
  /// 
  /// Closes the Bluetooth connection and cleans up resources.
  /// 
  /// Requirements: 9.1
  Future<void> disconnect(String deviceId) async {
    try {
      final device = _connectedDevices[deviceId];
      if (device != null) {
        await device.disconnect();
        _connectedDevices.remove(deviceId);
      }

      final subscription = _connectionSubscriptions[deviceId];
      if (subscription != null) {
        await subscription.cancel();
        _connectionSubscriptions.remove(deviceId);
      }
    } catch (e) {
      throw BluetoothException('Disconnection failed: $e');
    }
  }

  /// Check if a device is currently connected
  bool isConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId);
  }

  /// Get the Bluetooth device for a given device ID
  BluetoothDevice? getDevice(String deviceId) {
    return _connectedDevices[deviceId];
  }

  /// Handle device disconnection
  void _handleDisconnection(String deviceId) {
    _connectedDevices.remove(deviceId);
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);
  }

  /// Clean up resources
  Future<void> dispose() async {
    for (final deviceId in _connectedDevices.keys.toList()) {
      await disconnect(deviceId);
    }
    await _discoveryController.close();
  }
}

/// Exception thrown when Bluetooth operations fail
class BluetoothException implements Exception {
  final String message;
  
  BluetoothException(this.message);
  
  @override
  String toString() => 'BluetoothException: $message';
}
