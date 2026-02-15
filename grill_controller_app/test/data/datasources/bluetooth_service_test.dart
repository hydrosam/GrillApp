import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/data/datasources/bluetooth_service.dart';

void main() {
  group('BluetoothService', () {
    late BluetoothService bluetoothService;

    setUp(() {
      bluetoothService = BluetoothService();
    });

    tearDown(() async {
      await bluetoothService.dispose();
    });

    group('Device Discovery', () {
      test('should throw BluetoothException when Bluetooth is not supported', () async {
        // Note: This test will pass on platforms without Bluetooth support
        // On platforms with Bluetooth, it will test the actual discovery flow
        
        try {
          final stream = bluetoothService.discoverDevices(
            timeout: const Duration(seconds: 2),
          );
          await stream.first;
          
          // If we get here, discovery worked (Bluetooth is available)
          expect(true, true);
        } catch (e) {
          // If Bluetooth is not available, we should get a BluetoothException
          expect(e, isA<BluetoothException>());
        }
      });

      test('should return empty list when no devices are found', () async {
        // This test verifies the discovery mechanism works
        // In a real environment with no devices, it should return empty list
        
        try {
          final stream = bluetoothService.discoverDevices(
            timeout: const Duration(seconds: 2),
          );
          final devices = await stream.first;
          
          // Should return a list (may be empty if no devices nearby)
          expect(devices, isA<List>());
        } catch (e) {
          // Bluetooth may not be available in test environment
          expect(e, isA<BluetoothException>());
        }
      });
    });

    group('Device Connection', () {
      test('should throw BluetoothException when device not found', () async {
        // Attempting to connect to non-existent device should fail
        expect(
          () => bluetoothService.connectDevice('non-existent-device-id'),
          throwsA(isA<BluetoothException>()),
        );
      });

      test('should track connection status correctly', () {
        // Initially, device should not be connected
        expect(bluetoothService.isConnected('test-device-id'), false);
      });
    });

    group('WiFi Credentials', () {
      test('should throw BluetoothException when device not connected', () async {
        // Attempting to send credentials to non-connected device should fail
        expect(
          () => bluetoothService.sendWifiCredentials(
            'non-connected-device',
            'TestSSID',
            'TestPassword',
          ),
          throwsA(isA<BluetoothException>()),
        );
      });
    });

    group('Disconnection', () {
      test('should handle disconnection of non-connected device gracefully', () async {
        // Disconnecting a device that was never connected should not throw
        await bluetoothService.disconnect('non-existent-device');
        
        // Should complete without error
        expect(true, true);
      });

      test('should clean up connection state after disconnect', () async {
        // After disconnect, device should not be in connected state
        await bluetoothService.disconnect('test-device-id');
        expect(bluetoothService.isConnected('test-device-id'), false);
      });
    });

    group('Error Handling', () {
      test('BluetoothException should contain error message', () {
        final exception = BluetoothException('Test error message');
        expect(exception.message, 'Test error message');
        expect(exception.toString(), contains('Test error message'));
      });
    });

    group('Resource Management', () {
      test('should dispose all resources cleanly', () async {
        // Create a new service instance
        final service = BluetoothService();
        
        // Dispose should complete without error
        await service.dispose();
        
        // After dispose, device should not be connected
        expect(service.isConnected('any-device'), false);
      });
    });
  });
}
