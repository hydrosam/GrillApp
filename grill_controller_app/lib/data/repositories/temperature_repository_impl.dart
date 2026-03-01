import 'dart:async';
import '../../domain/entities/temperature_reading.dart';
import '../../domain/repositories/temperature_repository.dart';
import '../datasources/temperature_database_helper.dart';
import '../datasources/ikamand_http_service.dart';
import '../datasources/local_storage_service.dart';

/// Concrete implementation of TemperatureRepository
/// 
/// Uses TemperatureDatabaseHelper for SQLite storage and IKamandHttpService
/// for streaming temperature data from devices. Automatically saves readings
/// to the database during active cook sessions.
/// 
/// Requirements: 2.2, 2.3, 2.6
class TemperatureRepositoryImpl implements TemperatureRepository {
  final TemperatureDatabaseHelper _databaseHelper;
  final IKamandHttpService _httpService;
  final Map<String, StreamController<TemperatureReading>> _temperatureControllers = {};
  final Map<String, StreamSubscription> _statusSubscriptions = {};
  final Map<String, String?> _deviceSessionMap = {}; // Track active session per device

  TemperatureRepositoryImpl({
    required TemperatureDatabaseHelper databaseHelper,
    required IKamandHttpService httpService,
  })  : _databaseHelper = databaseHelper,
        _httpService = httpService;

  @override
  Stream<TemperatureReading> watchTemperatures(String deviceId) {
    // Return existing stream if already watching
    if (_temperatureControllers.containsKey(deviceId)) {
      return _temperatureControllers[deviceId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<TemperatureReading>.broadcast();
    _temperatureControllers[deviceId] = controller;

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
          // Convert status to temperature readings
          final readings = _httpService.statusToTemperatureReadings(status, deviceId);
          
          // Emit each reading to the stream
          for (final reading in readings) {
            if (!controller.isClosed) {
              controller.add(reading);
            }
            
            // Auto-save reading if there's an active session
            final sessionId = _deviceSessionMap[deviceId];
            if (sessionId != null) {
              _databaseHelper.insertReading(reading, sessionId).catchError((error) {
                // Log error but don't interrupt the stream
                // In production, use a proper logging framework
                // ignore: avoid_print
                print('Failed to save temperature reading: $error');
                return ''; // Return empty string to satisfy return type
              });
            }
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
      controller.addError(Exception('Device not connected to WiFi'));
    }

    return controller.stream;
  }

  @override
  Future<void> saveReading(TemperatureReading reading) async {
    try {
      // Find the active session for this device
      // Extract device ID from probe ID (format: deviceId_probeType)
      final deviceId = reading.probeId.split('_').first;
      
      // Get or create session ID
      String? sessionId = _deviceSessionMap[deviceId];
      
      // No active session, use a default session ID
      // In production, this should be handled by the session management layer
      sessionId ??= 'default_session';
      
      await _databaseHelper.insertReading(reading, sessionId);
    } catch (e) {
      throw Exception('Failed to save temperature reading: $e');
    }
  }

  @override
  Future<List<TemperatureReading>> getHistory(
    String deviceId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      // Get all readings in the time range
      final allReadings = await _databaseHelper.getReadingsByTimeRange(start, end);
      
      // Filter readings for this device
      // Probe IDs are formatted as: deviceId_probeType
      final deviceReadings = allReadings.where((reading) {
        return reading.probeId.startsWith('${deviceId}_');
      }).toList();
      
      return deviceReadings;
    } catch (e) {
      throw Exception('Failed to get temperature history: $e');
    }
  }

  @override
  Future<List<TemperatureReading>> getSessionHistory(String sessionId) async {
    try {
      return await _databaseHelper.getReadingsBySession(sessionId);
    } catch (e) {
      throw Exception('Failed to get session history: $e');
    }
  }

  @override
  Future<void> deleteOldReadings(DateTime before) async {
    try {
      await _databaseHelper.deleteReadingsOlderThan(before);
    } catch (e) {
      throw Exception('Failed to delete old readings: $e');
    }
  }

  @override
  Future<TemperatureReading?> getLatestReading(
    String deviceId,
    ProbeType probeType,
  ) async {
    try {
      // Construct probe ID
      final probeId = '${deviceId}_${probeType.name}';
      
      return await _databaseHelper.getLatestReadingForProbe(probeId);
    } catch (e) {
      throw Exception('Failed to get latest reading: $e');
    }
  }

  /// Set the active session for a device
  /// 
  /// This should be called when a cook session starts to enable
  /// automatic saving of temperature readings.
  /// 
  /// Requirements: 2.3, 10.4
  void setActiveSession(String deviceId, String? sessionId) {
    _deviceSessionMap[deviceId] = sessionId;
  }

  /// Get the active session ID for a device
  String? getActiveSession(String deviceId) {
    return _deviceSessionMap[deviceId];
  }

  /// Stop watching temperatures for a device
  /// 
  /// Cancels the temperature stream and cleans up resources.
  void stopWatching(String deviceId) {
    _statusSubscriptions[deviceId]?.cancel();
    _statusSubscriptions.remove(deviceId);
    
    _temperatureControllers[deviceId]?.close();
    _temperatureControllers.remove(deviceId);
    
    _deviceSessionMap.remove(deviceId);
  }

  /// Clean up resources
  void dispose() {
    for (final subscription in _statusSubscriptions.values) {
      subscription.cancel();
    }
    _statusSubscriptions.clear();
    
    for (final controller in _temperatureControllers.values) {
      controller.close();
    }
    _temperatureControllers.clear();
    
    _deviceSessionMap.clear();
  }
}
