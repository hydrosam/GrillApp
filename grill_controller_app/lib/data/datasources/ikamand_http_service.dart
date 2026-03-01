import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ikamand_status.dart';
import '../models/ikamand_command.dart';
import '../../domain/entities/temperature_reading.dart';
import '../../domain/entities/probe.dart';

/// HTTP service for iKamand device communication
/// 
/// Handles HTTP communication with iKamand devices over WiFi.
/// Implements status polling and command sending according to the iKamand protocol.
/// 
/// Requirements: 1.5, 9.2, 9.3
class IKamandHttpService {
  final http.Client _client;
  final Map<String, Timer?> _pollingTimers = {};
  final Map<String, StreamController<IKamandStatus>> _statusControllers = {};
  final Map<String, int> _reconnectionAttempts = {};
  final Map<String, Timer?> _reconnectionTimers = {};
  final StreamController<ReconnectionEvent> _reconnectionEventController = 
      StreamController<ReconnectionEvent>.broadcast();

  IKamandHttpService({http.Client? client}) 
      : _client = client ?? http.Client();

  /// Stream of reconnection events
  /// 
  /// Emits events when reconnection attempts are made or fail.
  /// 
  /// Requirements: 9.4, 9.5
  Stream<ReconnectionEvent> get reconnectionEvents => _reconnectionEventController.stream;

  /// Get the base URL for a device
  /// 
  /// Constructs the HTTP endpoint URL from the device's IP address.
  String _getBaseUrl(String deviceIp) {
    return 'http://$deviceIp';
  }

  /// Get device status endpoint
  String _getStatusEndpoint(String deviceIp) {
    return '${_getBaseUrl(deviceIp)}/status';
  }

  /// Get device command endpoint
  String _getCommandEndpoint(String deviceIp) {
    return '${_getBaseUrl(deviceIp)}/command';
  }

  /// Fetch current status from device
  /// 
  /// Makes an HTTP GET request to retrieve the current device status.
  /// 
  /// Requirements: 9.2, 9.3
  Future<IKamandStatus> getStatus(String deviceIp) async {
    try {
      final url = Uri.parse(_getStatusEndpoint(deviceIp));
      final response = await _client.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw IKamandHttpException('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return IKamandStatus.fromJson(json);
      } else {
        throw IKamandHttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on FormatException catch (e) {
      throw IKamandHttpException('Invalid JSON response: $e');
    } on http.ClientException catch (e) {
      throw IKamandHttpException('Network error: $e');
    } catch (e) {
      if (e is IKamandHttpException) rethrow;
      throw IKamandHttpException('Failed to get status: $e');
    }
  }

  /// Send command to device
  /// 
  /// Makes an HTTP POST request to send a command to the device.
  /// 
  /// Requirements: 9.2, 9.3
  Future<void> sendCommand(String deviceIp, IKamandCommand command) async {
    try {
      final url = Uri.parse(_getCommandEndpoint(deviceIp));
      final body = jsonEncode(command.toJson());
      
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw IKamandHttpException('Request timeout');
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw IKamandHttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on http.ClientException catch (e) {
      throw IKamandHttpException('Network error: $e');
    } catch (e) {
      if (e is IKamandHttpException) rethrow;
      throw IKamandHttpException('Failed to send command: $e');
    }
  }

  /// Start polling device status
  /// 
  /// Polls the device status at regular intervals and emits updates via stream.
  /// Default polling interval is 5 seconds (per Requirement 2.6).
  /// Automatically attempts reconnection on connection loss.
  /// 
  /// Requirements: 2.6, 9.2, 9.4
  Stream<IKamandStatus> startStatusPolling(
    String deviceIp, {
    Duration interval = const Duration(seconds: 5),
  }) {
    // Stop any existing polling for this device
    stopStatusPolling(deviceIp);

    // Reset reconnection attempts when starting fresh
    _reconnectionAttempts[deviceIp] = 0;
    cancelReconnection(deviceIp);

    // Create a new stream controller
    final controller = StreamController<IKamandStatus>.broadcast();
    _statusControllers[deviceIp] = controller;

    // Start polling timer
    _pollingTimers[deviceIp] = Timer.periodic(interval, (timer) async {
      try {
        final status = await getStatus(deviceIp);
        if (!controller.isClosed) {
          controller.add(status);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
        
        // Trigger automatic reconnection on error
        await attemptReconnection(deviceIp);
      }
    });

    // Also fetch immediately
    getStatus(deviceIp).then((status) {
      if (!controller.isClosed) {
        controller.add(status);
      }
    }).catchError((e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
      
      // Trigger automatic reconnection on error
      attemptReconnection(deviceIp);
    });

    return controller.stream;
  }

  /// Stop polling device status
  /// 
  /// Cancels the polling timer and closes the status stream.
  void stopStatusPolling(String deviceIp) {
    _pollingTimers[deviceIp]?.cancel();
    _pollingTimers.remove(deviceIp);
    
    _statusControllers[deviceIp]?.close();
    _statusControllers.remove(deviceIp);
  }

  /// Convert IKamandStatus to temperature readings
  /// 
  /// Extracts temperature readings from the status response for all active probes.
  /// 
  /// Requirements: 2.1, 2.2
  List<TemperatureReading> statusToTemperatureReadings(
    IKamandStatus status,
    String deviceId,
  ) {
    final readings = <TemperatureReading>[];
    final timestamp = DateTime.now();

    // Grill probe (always present)
    readings.add(TemperatureReading(
      probeId: '${deviceId}_grill',
      temperature: status.grillTemp,
      timestamp: timestamp,
      type: ProbeType.grill,
    ));

    // Food probe 1
    if (status.food1Temp != null) {
      readings.add(TemperatureReading(
        probeId: '${deviceId}_food1',
        temperature: status.food1Temp!,
        timestamp: timestamp,
        type: ProbeType.food1,
      ));
    }

    // Food probe 2
    if (status.food2Temp != null) {
      readings.add(TemperatureReading(
        probeId: '${deviceId}_food2',
        temperature: status.food2Temp!,
        timestamp: timestamp,
        type: ProbeType.food2,
      ));
    }

    // Food probe 3
    if (status.food3Temp != null) {
      readings.add(TemperatureReading(
        probeId: '${deviceId}_food3',
        temperature: status.food3Temp!,
        timestamp: timestamp,
        type: ProbeType.food3,
      ));
    }

    return readings;
  }

  /// Convert IKamandStatus to probe list
  /// 
  /// Creates a list of Probe entities from the status response.
  /// 
  /// Requirements: 2.1, 2.5
  List<Probe> statusToProbes(IKamandStatus status, String deviceId) {
    final probes = <Probe>[];

    // Grill probe (always present)
    probes.add(Probe(
      id: '${deviceId}_grill',
      type: ProbeType.grill,
      isActive: true,
      targetTemperature: status.targetTemp,
    ));

    // Food probe 1
    probes.add(Probe(
      id: '${deviceId}_food1',
      type: ProbeType.food1,
      isActive: status.food1Temp != null,
      targetTemperature: null,
    ));

    // Food probe 2
    probes.add(Probe(
      id: '${deviceId}_food2',
      type: ProbeType.food2,
      isActive: status.food2Temp != null,
      targetTemperature: null,
    ));

    // Food probe 3
    probes.add(Probe(
      id: '${deviceId}_food3',
      type: ProbeType.food3,
      isActive: status.food3Temp != null,
      targetTemperature: null,
    ));

    return probes;
  }

  /// Test device connectivity
  /// 
  /// Attempts to connect to the device and verify it responds.
  /// Returns true if the device is reachable and responds correctly.
  /// 
  /// Requirements: 1.5, 9.2
  Future<bool> testConnection(String deviceIp) async {
    try {
      await getStatus(deviceIp);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Attempt to reconnect to a device with exponential backoff
  /// 
  /// Automatically attempts to reconnect when connection is lost.
  /// Uses exponential backoff: 1s, 2s, 4s for the 3 attempts.
  /// After 3 failed attempts, emits a failure event.
  /// 
  /// Requirements: 9.4, 9.5
  Future<void> attemptReconnection(String deviceIp) async {
    // Cancel any existing reconnection timer
    _reconnectionTimers[deviceIp]?.cancel();
    
    // Get current attempt count (default to 0)
    final attemptCount = _reconnectionAttempts[deviceIp] ?? 0;
    
    // Check if we've exceeded the retry limit
    if (attemptCount >= 3) {
      if (!_reconnectionEventController.isClosed) {
        _reconnectionEventController.add(ReconnectionEvent(
          deviceIp: deviceIp,
          attemptNumber: attemptCount,
          status: ReconnectionStatus.failed,
          message: 'Reconnection failed after 3 attempts',
        ));
      }
      
      // Reset attempt count for future reconnection attempts
      _reconnectionAttempts[deviceIp] = 0;
      return;
    }
    
    // Increment attempt count
    final newAttemptCount = attemptCount + 1;
    _reconnectionAttempts[deviceIp] = newAttemptCount;
    
    // Calculate exponential backoff delay: 1s, 2s, 4s
    final delaySeconds = 1 << (newAttemptCount - 1); // 2^(n-1)
    final delay = Duration(seconds: delaySeconds);
    
    // Emit attempting event
    if (!_reconnectionEventController.isClosed) {
      _reconnectionEventController.add(ReconnectionEvent(
        deviceIp: deviceIp,
        attemptNumber: newAttemptCount,
        status: ReconnectionStatus.attempting,
        message: 'Attempting reconnection (attempt $newAttemptCount of 3) after ${delaySeconds}s',
      ));
    }
    
    // Schedule reconnection attempt after delay
    _reconnectionTimers[deviceIp] = Timer(delay, () async {
      try {
        // Test connection
        final isConnected = await testConnection(deviceIp);
        
        if (isConnected) {
          // Success! Reset attempt count
          _reconnectionAttempts[deviceIp] = 0;
          
          if (!_reconnectionEventController.isClosed) {
            _reconnectionEventController.add(ReconnectionEvent(
              deviceIp: deviceIp,
              attemptNumber: newAttemptCount,
              status: ReconnectionStatus.success,
              message: 'Reconnection successful',
            ));
          }
          
          // Restart polling if it was active
          if (_statusControllers.containsKey(deviceIp)) {
            startStatusPolling(deviceIp);
          }
        } else {
          // Failed, try again
          await attemptReconnection(deviceIp);
        }
      } catch (e) {
        // Error during reconnection, try again
        await attemptReconnection(deviceIp);
      }
    });
  }

  /// Cancel reconnection attempts for a device
  /// 
  /// Stops any ongoing reconnection attempts and resets the attempt count.
  /// 
  /// Requirements: 9.4
  void cancelReconnection(String deviceIp) {
    _reconnectionTimers[deviceIp]?.cancel();
    _reconnectionTimers.remove(deviceIp);
    _reconnectionAttempts.remove(deviceIp);
  }

  /// Clean up resources
  /// 
  /// Stops all polling timers, closes all stream controllers,
  /// and cancels all reconnection attempts.
  void dispose() {
    for (final deviceIp in _pollingTimers.keys.toList()) {
      stopStatusPolling(deviceIp);
      cancelReconnection(deviceIp);
    }
    _reconnectionEventController.close();
    _client.close();
  }
}

/// Exception thrown when iKamand HTTP operations fail
class IKamandHttpException implements Exception {
  final String message;

  IKamandHttpException(this.message);

  @override
  String toString() => 'IKamandHttpException: $message';
}

/// Status of a reconnection attempt
/// 
/// Requirements: 9.4, 9.5
enum ReconnectionStatus {
  /// Attempting to reconnect
  attempting,
  
  /// Reconnection successful
  success,
  
  /// Reconnection failed after all attempts
  failed,
}

/// Event emitted during reconnection attempts
/// 
/// Provides information about reconnection progress and status.
/// 
/// Requirements: 9.4, 9.5
class ReconnectionEvent {
  /// Device IP address
  final String deviceIp;
  
  /// Current attempt number (1-3)
  final int attemptNumber;
  
  /// Status of the reconnection attempt
  final ReconnectionStatus status;
  
  /// Human-readable message describing the event
  final String message;

  ReconnectionEvent({
    required this.deviceIp,
    required this.attemptNumber,
    required this.status,
    required this.message,
  });

  @override
  String toString() => 'ReconnectionEvent(deviceIp: $deviceIp, attempt: $attemptNumber, status: $status, message: $message)';
}
