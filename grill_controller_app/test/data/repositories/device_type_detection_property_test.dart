import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:grill_controller_app/data/repositories/device_repository_impl.dart';
import 'package:grill_controller_app/data/datasources/bluetooth_service.dart';
import 'package:grill_controller_app/data/datasources/ikamand_http_service.dart';
import 'package:grill_controller_app/data/datasources/local_storage_service.dart';
import 'package:grill_controller_app/data/models/device_model.dart';
import 'package:grill_controller_app/data/models/ikamand_status.dart';
import 'package:grill_controller_app/domain/entities/grill_device.dart';
import 'package:faker/faker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

// Mock classes
class MockBluetoothService extends Mock implements BluetoothService {}
class MockIKamandHttpService extends Mock implements IKamandHttpService {}

// Mock PathProviderPlatform for Hive initialization
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('hive_test_').path;
  }
}

void main() {
  group('Property 27: Device Type Detection', () {
    // Feature: grill-controller-app, Property 27: Device Type Detection
    // **Validates: Requirements 9.6**
    
    final faker = Faker();
    const int iterations = 100;
    
    late MockBluetoothService mockBluetoothService;
    late MockIKamandHttpService mockHttpService;
    late DeviceRepositoryImpl repository;
    late Box<DeviceModel> devicesBox;
    late String tempDir;

    setUpAll(() async {
      // Set up mock path provider for Hive
      PathProviderPlatform.instance = MockPathProviderPlatform();
      
      // Initialize Hive with a temporary directory
      tempDir = Directory.systemTemp.createTempSync('hive_test_').path;
      Hive.init(tempDir);
      
      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DeviceModelAdapter());
      }
    });

    setUp(() async {
      // Open a fresh box for each test
      devicesBox = await Hive.openBox<DeviceModel>('devices_test_${faker.guid.guid()}');
      LocalStorageService.setDevicesBox(devicesBox);
      
      mockBluetoothService = MockBluetoothService();
      mockHttpService = MockIKamandHttpService();
      
      // Stub dispose methods
      when(() => mockBluetoothService.dispose()).thenAnswer((_) async => {});
      when(() => mockHttpService.dispose()).thenReturn(null);
      
      repository = DeviceRepositoryImpl(
        bluetoothService: mockBluetoothService,
        httpService: mockHttpService,
      );
    });

    tearDown(() async {
      repository.dispose();
      await devicesBox.close();
      await devicesBox.deleteFromDisk();
    });

    tearDownAll(() async {
      await Hive.close();
      // Clean up temp directory
      try {
        Directory(tempDir).deleteSync(recursive: true);
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('iKamand devices should be correctly detected via successful HTTP protocol response', () async {
      for (int i = 0; i < iterations; i++) {
        // Generate random device data
        final deviceId = faker.guid.guid();
        final deviceName = faker.company.name();
        final deviceIp = '${faker.randomGenerator.integer(255, min: 1)}.${faker.randomGenerator.integer(255)}.${faker.randomGenerator.integer(255)}.${faker.randomGenerator.integer(255, min: 1)}';
        
        // Create device model with WiFi IP
        final deviceModel = DeviceModel(
          id: deviceId,
          name: deviceName,
          type: DeviceType.unknown.name,
          lastKnownIp: deviceIp,
        );
        
        await devicesBox.put(deviceId, deviceModel);
        
        // Mock successful HTTP status response (indicates iKamand device)
        final mockStatus = IKamandStatus(
          grillTemp: faker.randomGenerator.decimal(scale: 668, min: 32),
          food1Temp: faker.randomGenerator.boolean() ? faker.randomGenerator.decimal(scale: 668, min: 32) : null,
          food2Temp: faker.randomGenerator.boolean() ? faker.randomGenerator.decimal(scale: 668, min: 32) : null,
          food3Temp: faker.randomGenerator.boolean() ? faker.randomGenerator.decimal(scale: 668, min: 32) : null,
          fanSpeed: faker.randomGenerator.integer(101, min: 0),
          targetTemp: faker.randomGenerator.decimal(scale: 668, min: 32),
        );
        
        when(() => mockHttpService.getStatus(deviceIp))
            .thenAnswer((_) async => mockStatus);
        
        // Act: Detect device type
        final detectedType = await repository.detectDeviceType(deviceId);
        
        // Assert: Device should be detected as iKamand
        expect(detectedType, equals(DeviceType.ikamand),
            reason: 'Device with successful HTTP response should be detected as iKamand');
        
        // Verify the device type was persisted
        final updatedDevice = devicesBox.get(deviceId);
        expect(updatedDevice, isNotNull);
        expect(updatedDevice!.type, equals(DeviceType.ikamand.name),
            reason: 'Detected device type should be persisted to storage');
        
        // Verify HTTP service was called
        verify(() => mockHttpService.getStatus(deviceIp)).called(1);
      }
    });

    test('devices with failed HTTP protocol response should be detected as unknown', () async {
      for (int i = 0; i < iterations; i++) {
        // Generate random device data
        final deviceId = faker.guid.guid();
        final deviceName = faker.company.name();
        final deviceIp = '${faker.randomGenerator.integer(255, min: 1)}.${faker.randomGenerator.integer(255)}.${faker.randomGenerator.integer(255)}.${faker.randomGenerator.integer(255, min: 1)}';
        
        // Create device model with WiFi IP
        final deviceModel = DeviceModel(
          id: deviceId,
          name: deviceName,
          type: DeviceType.unknown.name,
          lastKnownIp: deviceIp,
        );
        
        await devicesBox.put(deviceId, deviceModel);
        
        // Mock failed HTTP status response (device doesn't support iKamand protocol)
        when(() => mockHttpService.getStatus(deviceIp))
            .thenThrow(IKamandHttpException('Connection failed'));
        
        // Act: Detect device type
        final detectedType = await repository.detectDeviceType(deviceId);
        
        // Assert: Device should be detected as unknown
        expect(detectedType, equals(DeviceType.unknown),
            reason: 'Device with failed HTTP response should be detected as unknown');
        
        // Verify the device type was persisted
        final updatedDevice = devicesBox.get(deviceId);
        expect(updatedDevice, isNotNull);
        expect(updatedDevice!.type, equals(DeviceType.unknown.name),
            reason: 'Detected device type should be persisted to storage');
        
        // Verify HTTP service was called
        verify(() => mockHttpService.getStatus(deviceIp)).called(1);
      }
    });

    test('devices without WiFi connection should return stored device type', () async {
      for (int i = 0; i < iterations; i++) {
        // Generate random device data
        final deviceId = faker.guid.guid();
        final deviceName = faker.company.name();
        
        // Randomly choose a stored device type
        final storedType = faker.randomGenerator.boolean() 
            ? DeviceType.ikamand 
            : DeviceType.unknown;
        
        // Create device model WITHOUT WiFi IP (Bluetooth only)
        final deviceModel = DeviceModel(
          id: deviceId,
          name: deviceName,
          type: storedType.name,
          lastKnownIp: null, // No WiFi connection
        );
        
        await devicesBox.put(deviceId, deviceModel);
        
        // Act: Detect device type
        final detectedType = await repository.detectDeviceType(deviceId);
        
        // Assert: Should return the stored device type
        expect(detectedType, equals(storedType),
            reason: 'Device without WiFi should return stored device type');
        
        // Verify HTTP service was NOT called (no WiFi connection)
        verifyNever(() => mockHttpService.getStatus(any()));
      }
    });

    test('device type detection should handle non-existent devices gracefully', () async {
      for (int i = 0; i < iterations; i++) {
        // Generate random device ID that doesn't exist
        final nonExistentDeviceId = faker.guid.guid();
        
        // Act & Assert: Should throw exception for non-existent device
        expect(
          () => repository.detectDeviceType(nonExistentDeviceId),
          throwsException,
          reason: 'Detecting type for non-existent device should throw exception',
        );
      }
    });

    test('device type detection should be idempotent - multiple calls return same result', () async {
      for (int i = 0; i < iterations; i++) {
        // Generate random device data
        final deviceId = faker.guid.guid();
        final deviceName = faker.company.name();
        final deviceIp = '${faker.randomGenerator.integer(255, min: 1)}.${faker.randomGenerator.integer(255)}.${faker.randomGenerator.integer(255)}.${faker.randomGenerator.integer(255, min: 1)}';
        
        // Create device model with WiFi IP
        final deviceModel = DeviceModel(
          id: deviceId,
          name: deviceName,
          type: DeviceType.unknown.name,
          lastKnownIp: deviceIp,
        );
        
        await devicesBox.put(deviceId, deviceModel);
        
        // Mock HTTP response
        final mockStatus = IKamandStatus(
          grillTemp: faker.randomGenerator.decimal(scale: 668, min: 32),
          food1Temp: null,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: faker.randomGenerator.integer(101, min: 0),
          targetTemp: faker.randomGenerator.decimal(scale: 668, min: 32),
        );
        
        when(() => mockHttpService.getStatus(deviceIp))
            .thenAnswer((_) async => mockStatus);
        
        // Act: Detect device type multiple times
        final firstDetection = await repository.detectDeviceType(deviceId);
        final secondDetection = await repository.detectDeviceType(deviceId);
        final thirdDetection = await repository.detectDeviceType(deviceId);
        
        // Assert: All detections should return the same result
        expect(firstDetection, equals(secondDetection),
            reason: 'Multiple device type detections should return consistent results');
        expect(secondDetection, equals(thirdDetection),
            reason: 'Multiple device type detections should return consistent results');
        expect(firstDetection, equals(DeviceType.ikamand),
            reason: 'Device should be consistently detected as iKamand');
      }
    });

    test('device type detection should correctly update from unknown to ikamand when WiFi is added', () async {
      for (int i = 0; i < iterations; i++) {
        // Generate random device data
        final deviceId = faker.guid.guid();
        final deviceName = faker.company.name();
        final deviceIp = '${faker.randomGenerator.integer(255, min: 1)}.${faker.randomGenerator.integer(255)}.${faker.randomGenerator.integer(255)}.${faker.randomGenerator.integer(255, min: 1)}';
        
        // Create device model WITHOUT WiFi IP initially
        final deviceModel = DeviceModel(
          id: deviceId,
          name: deviceName,
          type: DeviceType.unknown.name,
          lastKnownIp: null,
        );
        
        await devicesBox.put(deviceId, deviceModel);
        
        // First detection: No WiFi, should return unknown
        final firstDetection = await repository.detectDeviceType(deviceId);
        expect(firstDetection, equals(DeviceType.unknown),
            reason: 'Device without WiFi should initially be unknown');
        
        // Now add WiFi IP to the device
        deviceModel.lastKnownIp = deviceIp;
        await deviceModel.save();
        
        // Mock successful HTTP response
        final mockStatus = IKamandStatus(
          grillTemp: faker.randomGenerator.decimal(scale: 668, min: 32),
          food1Temp: null,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: faker.randomGenerator.integer(101, min: 0),
          targetTemp: faker.randomGenerator.decimal(scale: 668, min: 32),
        );
        
        when(() => mockHttpService.getStatus(deviceIp))
            .thenAnswer((_) async => mockStatus);
        
        // Second detection: With WiFi, should detect as iKamand
        final secondDetection = await repository.detectDeviceType(deviceId);
        expect(secondDetection, equals(DeviceType.ikamand),
            reason: 'Device with WiFi and successful HTTP response should be detected as iKamand');
        
        // Verify the transition was persisted
        final updatedDevice = devicesBox.get(deviceId);
        expect(updatedDevice!.type, equals(DeviceType.ikamand.name),
            reason: 'Device type transition should be persisted');
      }
    });
  });
}
