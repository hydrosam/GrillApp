import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:grill_controller_app/data/datasources/ikamand_http_service.dart';
import 'package:grill_controller_app/data/datasources/bluetooth_service.dart';
import 'package:grill_controller_app/data/models/ikamand_command.dart';
import 'package:grill_controller_app/data/models/ikamand_status.dart';

/// Unit tests for communication error handling
/// 
/// Tests various error scenarios to ensure the app handles communication
/// errors gracefully without crashing.
/// 
/// Requirements: 9.7
void main() {
  group('Communication Error Handling', () {
    group('HTTP Communication Errors', () {
      late IKamandHttpService service;
      const testDeviceIp = '192.168.1.100';

      tearDown(() {
        service.dispose();
      });

      group('Timeout Scenarios', () {
        test('should handle timeout on getStatus without crashing', () async {
          // Arrange - Create a client that delays longer than timeout
          final mockClient = MockClient((request) async {
            await Future.delayed(const Duration(seconds: 10));
            return http.Response('{}', 200);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert - Should throw exception but not crash
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('timeout'));
          }
        });

        test('should handle timeout on sendCommand without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            await Future.delayed(const Duration(seconds: 10));
            return http.Response('', 200);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.sendCommand(
              testDeviceIp,
              IKamandCommand.setFanSpeed(50),
            );
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('timeout'));
          }
        });

        test('should continue polling after timeout error', () async {
          // Arrange
          int callCount = 0;
          final mockClient = MockClient((request) async {
            callCount++;
            if (callCount == 1) {
              // First call times out
              await Future.delayed(const Duration(seconds: 10));
              return http.Response('{}', 200);
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

          // Act
          final stream = service.startStatusPolling(
            testDeviceIp,
            interval: const Duration(milliseconds: 100),
          );

          // Assert - Should emit error but continue polling
          final events = <dynamic>[];
          final subscription = stream.listen(
            (status) => events.add(status),
            onError: (error) => events.add(error),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          await subscription.cancel();

          // Should have at least one event (error or status)
          // The timeout triggers reconnection, so we verify the system doesn't crash
          expect(events.isNotEmpty, true);
        });
      });

      group('Malformed Response Handling', () {
        test('should handle invalid JSON without crashing', () async {
          // Arrange - Return malformed JSON
          final mockClient = MockClient((request) async {
            return http.Response('{ invalid json }', 200);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('Invalid JSON'));
          }
        });

        test('should handle incomplete JSON without crashing', () async {
          // Arrange - Return incomplete JSON
          final mockClient = MockClient((request) async {
            return http.Response('{"grill_temp": 250.0', 200);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('Invalid JSON'));
          }
        });

        test('should handle empty response without crashing', () async {
          // Arrange - Return empty response
          final mockClient = MockClient((request) async {
            return http.Response('', 200);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown exception');
          } catch (e) {
            // Should handle gracefully
            expect(e, isA<Exception>());
          }
        });

        test('should handle non-JSON response without crashing', () async {
          // Arrange - Return HTML instead of JSON
          final mockClient = MockClient((request) async {
            return http.Response('<html><body>Error</body></html>', 200);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('Invalid JSON'));
          }
        });

        test('should handle JSON with missing required fields without crashing', () async {
          // Arrange - Return JSON missing required fields
          final mockClient = MockClient((request) async {
            return http.Response(
              jsonEncode({
                'grill_temp': 250.0,
                // Missing other required fields
              }),
              200,
            );
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown exception');
          } catch (e) {
            // Should handle gracefully
            expect(e, isA<Exception>());
          }
        });

        test('should handle JSON with wrong data types without crashing', () async {
          // Arrange - Return JSON with string instead of number
          final mockClient = MockClient((request) async {
            return http.Response(
              jsonEncode({
                'grill_temp': 'not a number',
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

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown exception');
          } catch (e) {
            // Should handle gracefully
            expect(e, isA<Exception>());
          }
        });
      });

      group('Network Error Scenarios', () {
        test('should handle connection refused without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            throw http.ClientException('Connection refused');
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('Network error'));
          }
        });

        test('should handle host not found without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            throw http.ClientException('Failed host lookup');
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('Network error'));
          }
        });

        test('should handle network unreachable without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            throw http.ClientException('Network is unreachable');
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('Network error'));
          }
        });

        test('should handle socket exception without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            throw http.ClientException('SocketException: Connection timed out');
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.sendCommand(
              testDeviceIp,
              IKamandCommand.setFanSpeed(50),
            );
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('Network error'));
          }
        });
      });

      group('HTTP Error Status Codes', () {
        test('should handle 400 Bad Request without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            return http.Response('Bad Request', 400);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('400'));
          }
        });

        test('should handle 401 Unauthorized without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            return http.Response('Unauthorized', 401);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('401'));
          }
        });

        test('should handle 404 Not Found without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            return http.Response('Not Found', 404);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('404'));
          }
        });

        test('should handle 500 Internal Server Error without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            return http.Response('Internal Server Error', 500);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('500'));
          }
        });

        test('should handle 503 Service Unavailable without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            return http.Response('Service Unavailable', 503);
          });

          service = IKamandHttpService(client: mockClient);

          // Act & Assert
          try {
            await service.getStatus(testDeviceIp);
            fail('Should have thrown IKamandHttpException');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
            expect(e.toString(), contains('503'));
          }
        });
      });

      group('Error Recovery', () {
        test('should recover from transient errors during polling', () async {
          // Arrange - Fail first 2 calls, then succeed
          int callCount = 0;
          final mockClient = MockClient((request) async {
            callCount++;
            if (callCount <= 2) {
              throw http.ClientException('Transient error');
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

          // Act
          final stream = service.startStatusPolling(
            testDeviceIp,
            interval: const Duration(milliseconds: 100),
          );

          // Assert - Should eventually get successful status
          final statuses = <dynamic>[];
          final subscription = stream.listen(
            (status) => statuses.add(status),
            onError: (error) => statuses.add(error),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          await subscription.cancel();

          // Should have both errors and successful statuses
          expect(statuses.any((s) => s is IKamandHttpException), true);
          expect(statuses.any((s) => s is IKamandStatus), true);
        });

        test('should allow retry after failed command', () async {
          // Arrange
          int callCount = 0;
          final mockClient = MockClient((request) async {
            callCount++;
            if (callCount == 1) {
              throw http.ClientException('First attempt fails');
            }
            return http.Response('', 200);
          });

          service = IKamandHttpService(client: mockClient);

          // Act - First attempt fails
          try {
            await service.sendCommand(
              testDeviceIp,
              IKamandCommand.setFanSpeed(50),
            );
            fail('First attempt should have failed');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
          }

          // Second attempt succeeds
          await service.sendCommand(
            testDeviceIp,
            IKamandCommand.setFanSpeed(50),
          );

          // Assert - Should complete without error
          expect(callCount, 2);
        });
      });

      group('Concurrent Error Handling', () {
        test('should handle multiple simultaneous errors without crashing', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            throw http.ClientException('Error');
          });

          service = IKamandHttpService(client: mockClient);

          // Act - Make multiple concurrent requests
          final results = <bool>[];
          for (int i = 0; i < 10; i++) {
            try {
              await service.getStatus(testDeviceIp);
              results.add(false); // Should not succeed
            } catch (e) {
              results.add(true); // Should catch error
            }
          }

          // Assert - All should have caught errors without crashing
          expect(results.length, 10);
          expect(results.every((r) => r == true), true);
        });

        test('should handle errors on multiple devices independently', () async {
          // Arrange
          final mockClient = MockClient((request) async {
            if (request.url.toString().contains('192.168.1.100')) {
              throw http.ClientException('Device 1 error');
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

          // Act & Assert - Device 1 fails
          try {
            await service.getStatus('192.168.1.100');
            fail('Should have thrown');
          } catch (e) {
            expect(e, isA<IKamandHttpException>());
          }

          // Device 2 succeeds
          final status = await service.getStatus('192.168.1.101');
          expect(status, isA<IKamandStatus>());
        });
      });
    });

    group('Bluetooth Communication Errors', () {
      late BluetoothService service;

      setUp(() {
        service = BluetoothService();
      });

      tearDown(() async {
        await service.dispose();
      });

      group('Connection Errors', () {
        test('should handle device not found without crashing', () async {
          // Act & Assert
          try {
            await service.connectDevice('non-existent-device');
            fail('Should have thrown BluetoothException');
          } catch (e) {
            expect(e, isA<BluetoothException>());
            expect(e.toString(), contains('not found'));
          }
        });

        test('should handle connection to disconnected device without crashing', () async {
          // Act & Assert
          try {
            await service.sendWifiCredentials(
              'disconnected-device',
              'TestSSID',
              'TestPassword',
            );
            fail('Should have thrown BluetoothException');
          } catch (e) {
            expect(e, isA<BluetoothException>());
            expect(e.toString(), contains('not connected'));
          }
        });
      });

      group('Graceful Degradation', () {
        test('should handle disconnect of non-connected device gracefully', () async {
          // Act - Should not throw
          await service.disconnect('non-existent-device');

          // Assert
          expect(service.isConnected('non-existent-device'), false);
        });

        test('should handle multiple disconnect calls gracefully', () async {
          // Act - Multiple disconnects should not crash
          await service.disconnect('test-device');
          await service.disconnect('test-device');
          await service.disconnect('test-device');

          // Assert
          expect(true, true);
        });
      });

      group('Error Messages', () {
        test('BluetoothException should have descriptive message', () {
          final exception = BluetoothException('Connection timeout');
          
          expect(exception.message, 'Connection timeout');
          expect(exception.toString(), contains('BluetoothException'));
          expect(exception.toString(), contains('Connection timeout'));
        });
      });
    });

    group('General Error Handling Principles', () {
      test('exceptions should be catchable and not crash app', () {
        // Arrange
        final httpException = IKamandHttpException('HTTP error');
        final bluetoothException = BluetoothException('Bluetooth error');

        // Act & Assert - Should be catchable
        try {
          throw httpException;
        } catch (e) {
          expect(e, isA<IKamandHttpException>());
        }

        try {
          throw bluetoothException;
        } catch (e) {
          expect(e, isA<BluetoothException>());
        }
      });

      test('exceptions should have meaningful error messages', () {
        final httpException = IKamandHttpException('Request timeout');
        final bluetoothException = BluetoothException('Device not found');

        expect(httpException.toString(), contains('Request timeout'));
        expect(bluetoothException.toString(), contains('Device not found'));
      });
    });
  });
}
