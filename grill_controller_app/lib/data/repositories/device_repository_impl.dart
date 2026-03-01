import 'dart:async';
import '../../domain/entities/grill_device.dart';
import '../../domain/entities/fan_status.dart';
import '../../domain/repositories/device_repository.dart';
import '../datasources/bluetooth_service.dart';
import '../datasources/ikamand_http_service.dart';
import '../datasources/local_storage_service.dart';
import '../models/device_model.dart';
import '../models/ikamand_command.dart';

/// Concrete implementation of DeviceRepository
/// 
/// Uses BluetoothService for initial pairing and IKamandHttpService
/// for WiFi-based communication. Persists device information using
/// LocalStorageService.
/// 
/// Requirements: 1.2, 1.3, 1.5, 9.6
class DeviceRepositoryImpl implements DeviceRepository {
  final BluetoothService _bluetoothService;
  final IKamandHttpService _httpService;
  final Map<String, StreamController<GrillDevice>> _deviceControllers = {};
  final Map<String, StreamSubscription> _statusSubscriptions = {};

  DeviceRepositoryImpl({
    required BluetoothService bluetoothService,
    required IKamandHttpService httpService,
  })  : _bluetoothService = bluetoothService,
        _httpService = httpService;

  @override
  Stream<GrillDevice> watchDevice(String deviceId) {
    // Return existing stream if already watching
    if (_deviceControllers.containsKey(deviceId)) {
      return _deviceControllers[deviceId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<GrillDevice>.broadcast();
    _deviceControllers[deviceId] = controller;

    // Get device from storage to get IP address
    final devicesBox = LocalStorageService.getDevicesBox();
    final deviceModel = devicesBox.get(deviceId);

    if (deviceModel == null) {
      controller.addError(Exception('Device not found: $deviceId'));
      return controller.stream;
    }

    // If device has WiFi IP, start polling status
    if (deviceModel.lastKnownIp != null) {
      final statusStream = _httpService.startStatusPolling(deviceModel.lastKnownIp!);
      
      final subscription = statusStream.listen(
        (status) {
          // Convert status to GrillDevice
          final device = GrillDevice(
            id: deviceId,
            name: deviceModel.name,
            type: _parseDeviceType(deviceModel.type),
            status: ConnectionStatus.wifi,
            probes: _httpService.statusToProbes(status, deviceId),
            fanStatus: FanStatus(
              speed: status.fanSpeed,
              isAutomatic: true, // Assume automatic unless manually set
              lastUpdate: DateTime.now(),
            ),
          );
          
          if (!controller.isClosed) {
            controller.add(device);
          }
        },
        onError: (error) {
          if (!controller.isClosed) {
            controller.addError(error);
          }
        },
      );
      
      _statusSubscriptions[deviceId] = subscription;
    } else {
      // Device only has Bluetooth connection
      final device = GrillDevice(
        id: deviceId,
        name: deviceModel.name,
        type: _parseDeviceType(deviceModel.type),
        status: ConnectionStatus.bluetooth,
        probes: [],
        fanStatus: FanStatus(
          speed: 0,
          isAutomatic: false,
          lastUpdate: DateTime.now(),
        ),
      );
      
      controller.add(device);
    }

    return controller.stream;
  }

  @override
  Future<List<GrillDevice>> discoverDevices() async {
    try {
      // Use Bluetooth service to discover devices
      final discoveryStream = _bluetoothService.discoverDevices();
      
      // Get the first (and only) emission from the stream
      final devices = await discoveryStream.first;
      
      return devices;
    } catch (e) {
      throw Exception('Device discovery failed: $e');
    }
  }

  @override
  Future<void> connectBluetooth(String deviceId) async {
    try {
      // Connect via Bluetooth
      await _bluetoothService.connectDevice(deviceId);
      
      // Save device to storage
      final devicesBox = LocalStorageService.getDevicesBox();
      
      // Check if device already exists
      DeviceModel? deviceModel = devicesBox.get(deviceId);
      
      if (deviceModel == null) {
        // Create new device model
        deviceModel = DeviceModel(
          id: deviceId,
          name: 'Grill Device', // Default name, can be updated later
          type: DeviceType.unknown.name,
        );
        
        await devicesBox.put(deviceId, deviceModel);
      }
    } catch (e) {
      throw Exception('Bluetooth connection failed: $e');
    }
  }

  @override
  Future<void> sendWifiCredentials(
    String deviceId,
    String ssid,
    String password,
  ) async {
    try {
      // Send credentials via Bluetooth
      await _bluetoothService.sendWifiCredentials(deviceId, ssid, password);
      
      // Wait a moment for device to connect to WiFi
      await Future.delayed(const Duration(seconds: 5));
      
      // Try to detect device on network
      // For now, we'll need the user to provide the IP or use mDNS discovery
      // This is a simplified implementation
      
      // Update device status in storage
      final devicesBox = LocalStorageService.getDevicesBox();
      final deviceModel = devicesBox.get(deviceId);
      
      if (deviceModel != null) {
        // Store WiFi credentials in configuration (encrypted in production)
        deviceModel.configuration = {
          'ssid': ssid,
          'wifi_configured': true,
        };
        
        await deviceModel.save();
      }
    } catch (e) {
      throw Exception('Failed to send WiFi credentials: $e');
    }
  }

  @override
  Future<void> setFanSpeed(String deviceId, int speed) async {
    if (speed < 0 || speed > 100) {
      throw ArgumentError('Fan speed must be between 0 and 100');
    }

    try {
      // Get device IP from storage
      final devicesBox = LocalStorageService.getDevicesBox();
      final deviceModel = devicesBox.get(deviceId);
      
      if (deviceModel == null) {
        throw Exception('Device not found: $deviceId');
      }
      
      if (deviceModel.lastKnownIp == null) {
        throw Exception('Device not connected to WiFi');
      }
      
      // Send command via HTTP
      final command = IKamandCommand.setFanSpeed(speed);
      await _httpService.sendCommand(deviceModel.lastKnownIp!, command);
    } catch (e) {
      throw Exception('Failed to set fan speed: $e');
    }
  }

  @override
  Future<void> setTargetTemperature(String deviceId, double temperature) async {
    if (temperature < 32 || temperature > 1000) {
      throw ArgumentError('Temperature must be between 32°F and 1000°F');
    }

    try {
      // Get device IP from storage
      final devicesBox = LocalStorageService.getDevicesBox();
      final deviceModel = devicesBox.get(deviceId);
      
      if (deviceModel == null) {
        throw Exception('Device not found: $deviceId');
      }
      
      if (deviceModel.lastKnownIp == null) {
        throw Exception('Device not connected to WiFi');
      }
      
      // Send command via HTTP
      final command = IKamandCommand.setTargetTemp(temperature);
      await _httpService.sendCommand(deviceModel.lastKnownIp!, command);
    } catch (e) {
      throw Exception('Failed to set target temperature: $e');
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    try {
      // Stop watching device
      _statusSubscriptions[deviceId]?.cancel();
      _statusSubscriptions.remove(deviceId);
      
      _deviceControllers[deviceId]?.close();
      _deviceControllers.remove(deviceId);
      
      // Get device from storage
      final devicesBox = LocalStorageService.getDevicesBox();
      final deviceModel = devicesBox.get(deviceId);
      
      if (deviceModel != null) {
        // Disconnect Bluetooth if connected
        if (_bluetoothService.isConnected(deviceId)) {
          await _bluetoothService.disconnect(deviceId);
        }
        
        // Stop HTTP polling if active
        if (deviceModel.lastKnownIp != null) {
          _httpService.stopStatusPolling(deviceModel.lastKnownIp!);
        }
      }
    } catch (e) {
      throw Exception('Disconnection failed: $e');
    }
  }

  @override
  Future<DeviceType> detectDeviceType(String deviceId) async {
    try {
      // Get device from storage
      final devicesBox = LocalStorageService.getDevicesBox();
      final deviceModel = devicesBox.get(deviceId);
      
      if (deviceModel == null) {
        throw Exception('Device not found: $deviceId');
      }
      
      // If device has WiFi IP, try to detect type via HTTP
      if (deviceModel.lastKnownIp != null) {
        try {
          // Try to get status using iKamand protocol
          await _httpService.getStatus(deviceModel.lastKnownIp!);
          
          // If we successfully got status, it's an iKamand device
          deviceModel.type = DeviceType.ikamand.name;
          await deviceModel.save();
          
          return DeviceType.ikamand;
        } catch (e) {
          // If iKamand protocol fails, device type is unknown
          deviceModel.type = DeviceType.unknown.name;
          await deviceModel.save();
          
          return DeviceType.unknown;
        }
      }
      
      // If no WiFi connection, return stored type
      return _parseDeviceType(deviceModel.type);
    } catch (e) {
      throw Exception('Device type detection failed: $e');
    }
  }

  /// Update device IP address after WiFi connection
  /// 
  /// This should be called after the device successfully connects to WiFi
  /// and its IP address is discovered (e.g., via mDNS or user input).
  Future<void> updateDeviceIp(String deviceId, String ipAddress) async {
    try {
      final devicesBox = LocalStorageService.getDevicesBox();
      final deviceModel = devicesBox.get(deviceId);
      
      if (deviceModel == null) {
        throw Exception('Device not found: $deviceId');
      }
      
      // Update IP address
      deviceModel.lastKnownIp = ipAddress;
      await deviceModel.save();
      
      // Test connection
      final isConnected = await _httpService.testConnection(ipAddress);
      
      if (!isConnected) {
        throw Exception('Device not reachable at IP: $ipAddress');
      }
      
      // Detect device type
      await detectDeviceType(deviceId);
      
      // Disconnect Bluetooth as we're now on WiFi
      if (_bluetoothService.isConnected(deviceId)) {
        await _bluetoothService.disconnect(deviceId);
      }
    } catch (e) {
      throw Exception('Failed to update device IP: $e');
    }
  }

  /// Parse device type from string
  DeviceType _parseDeviceType(String typeString) {
    try {
      return DeviceType.values.firstWhere((e) => e.name == typeString);
    } catch (e) {
      return DeviceType.unknown;
    }
  }

  /// Clean up resources
  void dispose() {
    for (final subscription in _statusSubscriptions.values) {
      subscription.cancel();
    }
    _statusSubscriptions.clear();
    
    for (final controller in _deviceControllers.values) {
      controller.close();
    }
    _deviceControllers.clear();
    
    _bluetoothService.dispose();
    _httpService.dispose();
  }
}
