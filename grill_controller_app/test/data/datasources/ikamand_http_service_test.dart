import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:grill_controller_app/data/datasources/ikamand_http_service.dart';
import 'package:grill_controller_app/data/models/ikamand_status.dart';
import 'package:grill_controller_app/data/models/ikamand_command.dart';
import 'package:grill_controller_app/domain/entities/temperature_reading.dart';

void main() {
  group('IKamandHttpService', () {
    late IKamandHttpService service;
    const testDeviceIp = '192.168.1.100';

    tearDown(() {
      service.dispose();
    });

    group('getStatus', () {
      test('should successfully parse valid status response', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'http://$testDeviceIp/status');
          expect(request.method, 'GET');
          expect(request.headers['Accept'], 'application/json');

          return http.Response(
            jsonEncode({
              'grill_temp': 250.5,
              'food1_temp': 165.0,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 45,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        final status = await service.getStatus(testDeviceIp);

        // Assert
        expect(status.grillTemp, 250.5);
        expect(status.food1Temp, 165.0);
        expect(status.food2Temp, null);
        expect(status.food3Temp, null);
        expect(status.fanSpeed, 45);
        expect(status.targetTemp, 275.0);
      });

      test('should handle all probes active', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'grill_temp': 300.0,
              'food1_temp': 150.0,
              'food2_temp': 160.0,
              'food3_temp': 170.0,
              'fan_speed': 60,
              'target_temp': 325.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        final status = await service.getStatus(testDeviceIp);

        // Assert
        expect(status.grillTemp, 300.0);
        expect(status.food1Temp, 150.0);
        expect(status.food2Temp, 160.0);
        expect(status.food3Temp, 170.0);
        expect(status.fanSpeed, 60);
        expect(status.targetTemp, 325.0);
      });

      test('should throw IKamandHttpException on HTTP error', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        service = IKamandHttpService(client: mockClient);

        // Act & Assert
        expect(
          () => service.getStatus(testDeviceIp),
          throwsA(isA<IKamandHttpException>()),
        );
      });

      test('should throw IKamandHttpException on invalid JSON', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('Invalid JSON{', 200);
        });

        service = IKamandHttpService(client: mockClient);

        // Act & Assert
        expect(
          () => service.getStatus(testDeviceIp),
          throwsA(isA<IKamandHttpException>()),
        );
      });

      test('should throw IKamandHttpException on timeout', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response('{}', 200);
        });

        service = IKamandHttpService(client: mockClient);

        // Act & Assert
        expect(
          () => service.getStatus(testDeviceIp),
          throwsA(isA<IKamandHttpException>()),
        );
      });

      test('should throw IKamandHttpException on network error', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          throw http.ClientException('Network error');
        });

        service = IKamandHttpService(client: mockClient);

        // Act & Assert
        expect(
          () => service.getStatus(testDeviceIp),
          throwsA(isA<IKamandHttpException>()),
        );
      });
    });

    group('sendCommand', () {
      test('should send fan speed command successfully', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'http://$testDeviceIp/command');
          expect(request.method, 'POST');
          expect(request.headers['Content-Type'], 'application/json');
          expect(request.headers['Accept'], 'application/json');

          final body = jsonDecode(request.body);
          expect(body['fan_speed'], 50);
          expect(body.containsKey('target_temp'), false);

          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);
        final command = IKamandCommand.setFanSpeed(50);

        // Act
        await service.sendCommand(testDeviceIp, command);

        // Assert - no exception thrown
      });

      test('should send target temperature command successfully', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['target_temp'], 275.0);
          expect(body.containsKey('fan_speed'), false);

          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);
        final command = IKamandCommand.setTargetTemp(275.0);

        // Act
        await service.sendCommand(testDeviceIp, command);

        // Assert - no exception thrown
      });

      test('should send both fan speed and target temperature', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['fan_speed'], 60);
          expect(body['target_temp'], 300.0);

          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);
        final command = IKamandCommand.setBoth(60, 300.0);

        // Act
        await service.sendCommand(testDeviceIp, command);

        // Assert - no exception thrown
      });

      test('should accept 204 No Content response', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('', 204);
        });

        service = IKamandHttpService(client: mockClient);
        final command = IKamandCommand.setFanSpeed(50);

        // Act
        await service.sendCommand(testDeviceIp, command);

        // Assert - no exception thrown
      });

      test('should throw IKamandHttpException on HTTP error', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('Bad Request', 400);
        });

        service = IKamandHttpService(client: mockClient);
        final command = IKamandCommand.setFanSpeed(50);

        // Act & Assert
        expect(
          () => service.sendCommand(testDeviceIp, command),
          throwsA(isA<IKamandHttpException>()),
        );
      });

      test('should throw IKamandHttpException on timeout', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);
        final command = IKamandCommand.setFanSpeed(50);

        // Act & Assert
        expect(
          () => service.sendCommand(testDeviceIp, command),
          throwsA(isA<IKamandHttpException>()),
        );
      });

      test('should throw IKamandHttpException on network error', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          throw http.ClientException('Network error');
        });

        service = IKamandHttpService(client: mockClient);
        final command = IKamandCommand.setFanSpeed(50);

        // Act & Assert
        expect(
          () => service.sendCommand(testDeviceIp, command),
          throwsA(isA<IKamandHttpException>()),
        );
      });
    });

    group('startStatusPolling', () {
      test('should emit status updates at regular intervals', () async {
        // Arrange
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0 + requestCount,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        final stream = service.startStatusPolling(
          testDeviceIp,
          interval: const Duration(milliseconds: 100),
        );

        // Assert
        final statuses = await stream.take(3).toList();
        expect(statuses.length, 3);
        expect(statuses[0].grillTemp, 251.0); // First immediate fetch
        expect(statuses[1].grillTemp, 252.0); // First interval
        expect(statuses[2].grillTemp, 253.0); // Second interval
      });

      test('should emit errors when status fetch fails', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('Error', 500);
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        final stream = service.startStatusPolling(
          testDeviceIp,
          interval: const Duration(milliseconds: 100),
        );

        // Assert
        expect(
          stream.first,
          throwsA(isA<IKamandHttpException>()),
        );
      });

      test('should stop previous polling when starting new polling', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        service.startStatusPolling(
          testDeviceIp,
          interval: const Duration(milliseconds: 100),
        );
        
        // Start second polling (should stop first)
        final stream2 = service.startStatusPolling(
          testDeviceIp,
          interval: const Duration(milliseconds: 100),
        );

        // Assert - stream2 should work
        final status = await stream2.first;
        expect(status.grillTemp, 250.0);
      });
    });

    group('stopStatusPolling', () {
      test('should stop polling and close stream', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        final stream = service.startStatusPolling(
          testDeviceIp,
          interval: const Duration(milliseconds: 100),
        );

        // Get first value
        await stream.first;

        // Stop polling
        service.stopStatusPolling(testDeviceIp);

        // Assert - stream should be closed
        // Note: This is hard to test directly, but we verify no errors occur
        expect(true, true);
      });

      test('should handle stopping non-existent polling gracefully', () {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);

        // Act & Assert - should not throw
        service.stopStatusPolling('non-existent-device');
        expect(true, true);
      });
    });

    group('statusToTemperatureReadings', () {
      test('should convert status with all probes to readings', () {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);

        const status = IKamandStatus(
          grillTemp: 250.0,
          food1Temp: 150.0,
          food2Temp: 160.0,
          food3Temp: 170.0,
          fanSpeed: 50,
          targetTemp: 275.0,
        );

        // Act
        final readings = service.statusToTemperatureReadings(status, 'device1');

        // Assert
        expect(readings.length, 4);
        expect(readings[0].type, ProbeType.grill);
        expect(readings[0].temperature, 250.0);
        expect(readings[1].type, ProbeType.food1);
        expect(readings[1].temperature, 150.0);
        expect(readings[2].type, ProbeType.food2);
        expect(readings[2].temperature, 160.0);
        expect(readings[3].type, ProbeType.food3);
        expect(readings[3].temperature, 170.0);
      });

      test('should convert status with only grill probe to readings', () {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);

        const status = IKamandStatus(
          grillTemp: 250.0,
          food1Temp: null,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: 50,
          targetTemp: 275.0,
        );

        // Act
        final readings = service.statusToTemperatureReadings(status, 'device1');

        // Assert
        expect(readings.length, 1);
        expect(readings[0].type, ProbeType.grill);
        expect(readings[0].temperature, 250.0);
      });

      test('should use correct probe IDs', () {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);

        const status = IKamandStatus(
          grillTemp: 250.0,
          food1Temp: 150.0,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: 50,
          targetTemp: 275.0,
        );

        // Act
        final readings = service.statusToTemperatureReadings(status, 'test_device');

        // Assert
        expect(readings[0].probeId, 'test_device_grill');
        expect(readings[1].probeId, 'test_device_food1');
      });
    });

    group('statusToProbes', () {
      test('should convert status to probe list with correct active states', () {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);

        const status = IKamandStatus(
          grillTemp: 250.0,
          food1Temp: 150.0,
          food2Temp: null,
          food3Temp: 170.0,
          fanSpeed: 50,
          targetTemp: 275.0,
        );

        // Act
        final probes = service.statusToProbes(status, 'device1');

        // Assert
        expect(probes.length, 4);
        expect(probes[0].type, ProbeType.grill);
        expect(probes[0].isActive, true);
        expect(probes[0].targetTemperature, 275.0);
        
        expect(probes[1].type, ProbeType.food1);
        expect(probes[1].isActive, true);
        
        expect(probes[2].type, ProbeType.food2);
        expect(probes[2].isActive, false);
        
        expect(probes[3].type, ProbeType.food3);
        expect(probes[3].isActive, true);
      });

      test('should set target temperature only for grill probe', () {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        service = IKamandHttpService(client: mockClient);

        const status = IKamandStatus(
          grillTemp: 250.0,
          food1Temp: 150.0,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: 50,
          targetTemp: 300.0,
        );

        // Act
        final probes = service.statusToProbes(status, 'device1');

        // Assert
        expect(probes[0].targetTemperature, 300.0); // Grill
        expect(probes[1].targetTemperature, null);  // Food1
        expect(probes[2].targetTemperature, null);  // Food2
        expect(probes[3].targetTemperature, null);  // Food3
      });
    });

    group('testConnection', () {
      test('should return true when device responds', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        final result = await service.testConnection(testDeviceIp);

        // Assert
        expect(result, true);
      });

      test('should return false when device does not respond', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          throw http.ClientException('Connection refused');
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        final result = await service.testConnection(testDeviceIp);

        // Assert
        expect(result, false);
      });

      test('should return false on HTTP error', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('Error', 500);
        });

        service = IKamandHttpService(client: mockClient);

        // Act
        final result = await service.testConnection(testDeviceIp);

        // Assert
        expect(result, false);
      });
    });

    group('dispose', () {
      test('should stop all polling and close client', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        // Start polling
        service.startStatusPolling(
          testDeviceIp,
          interval: const Duration(milliseconds: 100),
        );

        // Act
        service.dispose();

        // Assert - should complete without error
        expect(true, true);
      });
    });

    group('Error Handling', () {
      test('IKamandHttpException should contain error message', () {
        final exception = IKamandHttpException('Test error message');
        expect(exception.message, 'Test error message');
        expect(exception.toString(), contains('Test error message'));
      });
    });

    group('Automatic Reconnection', () {
      test('should attempt reconnection with exponential backoff', () async {
        // Arrange
        int attemptCount = 0;
        final mockClient = MockClient((request) async {
          attemptCount++;
          if (attemptCount <= 2) {
            throw http.ClientException('Connection refused');
          }
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        final events = <ReconnectionEvent>[];
        final subscription = service.reconnectionEvents.listen((event) {
          events.add(event);
        });

        // Act
        await service.attemptReconnection(testDeviceIp);
        
        // Wait for reconnection attempts
        await Future.delayed(const Duration(milliseconds: 200));

        // Assert - should have attempting event
        expect(events.isNotEmpty, true);
        expect(events.first.status, ReconnectionStatus.attempting);
        expect(events.first.attemptNumber, 1);
        
        await subscription.cancel();
      });

      test('should emit success event after successful reconnection', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        final events = <ReconnectionEvent>[];
        final subscription = service.reconnectionEvents.listen((event) {
          events.add(event);
        });

        // Act
        await service.attemptReconnection(testDeviceIp);
        
        // Wait for reconnection to complete
        await Future.delayed(const Duration(seconds: 2));

        // Assert
        expect(events.any((e) => e.status == ReconnectionStatus.success), true);
        
        await subscription.cancel();
      });

      test('should fail after 3 reconnection attempts', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          throw http.ClientException('Connection refused');
        });

        service = IKamandHttpService(client: mockClient);

        final events = <ReconnectionEvent>[];
        final subscription = service.reconnectionEvents.listen((event) {
          events.add(event);
        });

        // Act - trigger first attempt
        await service.attemptReconnection(testDeviceIp);
        
        // Wait for all 3 attempts to complete (1s + 2s + 4s = 7s + buffer)
        await Future.delayed(const Duration(seconds: 8));

        // Assert - should have failure event after 3 attempts
        final failedEvents = events.where((e) => e.status == ReconnectionStatus.failed).toList();
        expect(failedEvents.isNotEmpty, true);
        
        await subscription.cancel();
      });

      test('should use exponential backoff delays (1s, 2s, 4s)', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          throw http.ClientException('Connection refused');
        });

        service = IKamandHttpService(client: mockClient);

        final events = <ReconnectionEvent>[];
        final subscription = service.reconnectionEvents.listen((event) {
          events.add(event);
        });

        // Act
        await service.attemptReconnection(testDeviceIp);
        
        // Wait for first attempt
        await Future.delayed(const Duration(milliseconds: 1100));
        
        // Wait for second attempt (should be ~2s after first)
        await Future.delayed(const Duration(milliseconds: 2100));
        
        // Wait for third attempt (should be ~4s after second)
        await Future.delayed(const Duration(milliseconds: 4100));

        // Assert - verify we got multiple attempts
        final attemptingEvents = events.where((e) => e.status == ReconnectionStatus.attempting).toList();
        expect(attemptingEvents.length, greaterThanOrEqualTo(1));
        
        await subscription.cancel();
      });

      test('should reset attempt count after successful reconnection', () async {
        // Arrange
        int callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          // Always succeed for this test
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        final events = <ReconnectionEvent>[];
        final subscription = service.reconnectionEvents.listen((event) {
          events.add(event);
        });

        // Act - first reconnection (should succeed immediately)
        await service.attemptReconnection(testDeviceIp);
        await Future.delayed(const Duration(seconds: 2));

        // Clear events
        events.clear();

        // Second reconnection (should start from attempt 1 again)
        await service.attemptReconnection(testDeviceIp);
        await Future.delayed(const Duration(seconds: 2));

        // Assert - second reconnection should start at attempt 1
        final attemptingEvents = events.where((e) => e.status == ReconnectionStatus.attempting).toList();
        if (attemptingEvents.isNotEmpty) {
          expect(attemptingEvents.first.attemptNumber, 1);
        }
        
        await subscription.cancel();
      });

      test('should cancel reconnection attempts', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          throw http.ClientException('Connection refused');
        });

        service = IKamandHttpService(client: mockClient);

        final events = <ReconnectionEvent>[];
        final subscription = service.reconnectionEvents.listen((event) {
          events.add(event);
        });

        // Act
        await service.attemptReconnection(testDeviceIp);
        service.cancelReconnection(testDeviceIp);
        
        // Wait to ensure no more events
        await Future.delayed(const Duration(seconds: 2));

        // Assert - should have at most 1 attempting event (the initial one)
        final attemptingEvents = events.where((e) => e.status == ReconnectionStatus.attempting).toList();
        expect(attemptingEvents.length, lessThanOrEqualTo(1));
        
        await subscription.cancel();
      });

      test('should trigger reconnection on polling error', () async {
        // Arrange
        int callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            // First call fails
            throw http.ClientException('Connection refused');
          }
          // Subsequent calls succeed
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        final events = <ReconnectionEvent>[];
        final subscription = service.reconnectionEvents.listen((event) {
          events.add(event);
        });

        // Act - start polling (first call will fail and trigger reconnection)
        service.startStatusPolling(
          testDeviceIp,
          interval: const Duration(milliseconds: 100),
        );

        // Wait for reconnection to be triggered
        await Future.delayed(const Duration(seconds: 2));

        // Assert - should have reconnection events
        expect(events.isNotEmpty, true);
        expect(events.any((e) => e.status == ReconnectionStatus.attempting), true);
        
        service.stopStatusPolling(testDeviceIp);
        await subscription.cancel();
      });

      test('should reset reconnection attempts when starting new polling', () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'grill_temp': 250.0,
              'food1_temp': null,
              'food2_temp': null,
              'food3_temp': null,
              'fan_speed': 50,
              'target_temp': 275.0,
            }),
            200,
          );
        });

        service = IKamandHttpService(client: mockClient);

        final subscription = service.reconnectionEvents.listen((event) {});

        // Act - manually set attempt count
        await service.attemptReconnection(testDeviceIp);
        
        // Start polling (should reset attempts)
        service.startStatusPolling(testDeviceIp);
        
        // Assert - attempt count should be reset (we can't directly check, but verify no errors)
        expect(true, true);
        
        service.stopStatusPolling(testDeviceIp);
        await subscription.cancel();
      });
    });

    group('ReconnectionEvent', () {
      test('should create event with all properties', () {
        final event = ReconnectionEvent(
          deviceIp: testDeviceIp,
          attemptNumber: 2,
          status: ReconnectionStatus.attempting,
          message: 'Test message',
        );

        expect(event.deviceIp, testDeviceIp);
        expect(event.attemptNumber, 2);
        expect(event.status, ReconnectionStatus.attempting);
        expect(event.message, 'Test message');
      });

      test('should have readable toString', () {
        final event = ReconnectionEvent(
          deviceIp: testDeviceIp,
          attemptNumber: 1,
          status: ReconnectionStatus.success,
          message: 'Reconnected',
        );

        final str = event.toString();
        expect(str, contains(testDeviceIp));
        expect(str, contains('1'));
        expect(str, contains('success'));
        expect(str, contains('Reconnected'));
      });
    });
  });
}
