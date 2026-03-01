import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/data/models/ikamand_command.dart';
import 'package:faker/faker.dart';

void main() {
  group('Property 24: iKamand Protocol Message Formatting', () {
    // Feature: grill-controller-app, Property 24: iKamand Protocol Message Formatting
    // **Validates: Requirements 9.3**
    
    final faker = Faker();
    const int iterations = 100;

    test('fan speed commands should format correctly with valid JSON structure', () {
      for (int i = 0; i < iterations; i++) {
        // Generate random fan speed (0-100)
        final fanSpeed = faker.randomGenerator.integer(101, min: 0);
        
        // Create command
        final command = IKamandCommand.setFanSpeed(fanSpeed);
        
        // Convert to JSON
        final json = command.toJson();
        
        // Verify JSON structure
        expect(json, isA<Map<String, dynamic>>());
        expect(json.containsKey('fan_speed'), isTrue, 
            reason: 'JSON must contain fan_speed key');
        expect(json['fan_speed'], equals(fanSpeed),
            reason: 'fan_speed value must match input');
        expect(json.containsKey('target_temp'), isFalse,
            reason: 'JSON should not contain target_temp when only setting fan speed');
        
        // Verify fan speed is in valid range
        expect(json['fan_speed'], greaterThanOrEqualTo(0));
        expect(json['fan_speed'], lessThanOrEqualTo(100));
      }
    });

    test('target temperature commands should format correctly with valid JSON structure', () {
      for (int i = 0; i < iterations; i++) {
        // Generate random target temperature (32-1000°F)
        final targetTemp = faker.randomGenerator.decimal(scale: 968, min: 32);
        
        // Create command
        final command = IKamandCommand.setTargetTemp(targetTemp);
        
        // Convert to JSON
        final json = command.toJson();
        
        // Verify JSON structure
        expect(json, isA<Map<String, dynamic>>());
        expect(json.containsKey('target_temp'), isTrue,
            reason: 'JSON must contain target_temp key');
        expect(json['target_temp'], equals(targetTemp),
            reason: 'target_temp value must match input');
        expect(json.containsKey('fan_speed'), isFalse,
            reason: 'JSON should not contain fan_speed when only setting target temperature');
        
        // Verify temperature is in valid range
        expect(json['target_temp'], greaterThanOrEqualTo(32));
        expect(json['target_temp'], lessThanOrEqualTo(1000));
      }
    });

    test('combined commands should format correctly with both fan speed and target temperature', () {
      for (int i = 0; i < iterations; i++) {
        // Generate random values
        final fanSpeed = faker.randomGenerator.integer(101, min: 0);
        final targetTemp = faker.randomGenerator.decimal(scale: 968, min: 32);
        
        // Create command
        final command = IKamandCommand.setBoth(fanSpeed, targetTemp);
        
        // Convert to JSON
        final json = command.toJson();
        
        // Verify JSON structure
        expect(json, isA<Map<String, dynamic>>());
        expect(json.containsKey('fan_speed'), isTrue,
            reason: 'JSON must contain fan_speed key');
        expect(json.containsKey('target_temp'), isTrue,
            reason: 'JSON must contain target_temp key');
        expect(json['fan_speed'], equals(fanSpeed),
            reason: 'fan_speed value must match input');
        expect(json['target_temp'], equals(targetTemp),
            reason: 'target_temp value must match input');
        
        // Verify values are in valid ranges
        expect(json['fan_speed'], greaterThanOrEqualTo(0));
        expect(json['fan_speed'], lessThanOrEqualTo(100));
        expect(json['target_temp'], greaterThanOrEqualTo(32));
        expect(json['target_temp'], lessThanOrEqualTo(1000));
      }
    });

    test('empty commands should format as empty JSON object', () {
      for (int i = 0; i < iterations; i++) {
        // Create empty command
        const command = IKamandCommand();
        
        // Convert to JSON
        final json = command.toJson();
        
        // Verify JSON structure
        expect(json, isA<Map<String, dynamic>>());
        expect(json.isEmpty, isTrue,
            reason: 'Empty command should produce empty JSON object');
      }
    });

    test('protocol round-trip: command serialization and deserialization should be consistent', () {
      for (int i = 0; i < iterations; i++) {
        // Generate random command type
        final commandType = faker.randomGenerator.integer(4);
        
        IKamandCommand command;
        switch (commandType) {
          case 0:
            // Fan speed only
            final fanSpeed = faker.randomGenerator.integer(101, min: 0);
            command = IKamandCommand.setFanSpeed(fanSpeed);
            break;
          case 1:
            // Target temp only
            final targetTemp = faker.randomGenerator.decimal(scale: 968, min: 32);
            command = IKamandCommand.setTargetTemp(targetTemp);
            break;
          case 2:
            // Both values
            final fanSpeed = faker.randomGenerator.integer(101, min: 0);
            final targetTemp = faker.randomGenerator.decimal(scale: 968, min: 32);
            command = IKamandCommand.setBoth(fanSpeed, targetTemp);
            break;
          default:
            // Empty command
            command = const IKamandCommand();
        }
        
        // Serialize to JSON
        final json = command.toJson();
        
        // Deserialize back to command
        final deserializedCommand = IKamandCommand.fromJson(json);
        
        // Verify round-trip consistency
        expect(deserializedCommand, equals(command),
            reason: 'Deserialized command should equal original command');
        expect(deserializedCommand.fanSpeed, equals(command.fanSpeed));
        expect(deserializedCommand.targetTemp, equals(command.targetTemp));
      }
    });

    test('protocol should use snake_case keys as per iKamand specification', () {
      for (int i = 0; i < iterations; i++) {
        // Generate random values
        final fanSpeed = faker.randomGenerator.integer(101, min: 0);
        final targetTemp = faker.randomGenerator.decimal(scale: 968, min: 32);
        
        // Create command with both values
        final command = IKamandCommand.setBoth(fanSpeed, targetTemp);
        
        // Convert to JSON
        final json = command.toJson();
        
        // Verify snake_case keys (not camelCase)
        expect(json.containsKey('fan_speed'), isTrue,
            reason: 'Protocol must use snake_case key "fan_speed"');
        expect(json.containsKey('target_temp'), isTrue,
            reason: 'Protocol must use snake_case key "target_temp"');
        expect(json.containsKey('fanSpeed'), isFalse,
            reason: 'Protocol must not use camelCase key "fanSpeed"');
        expect(json.containsKey('targetTemp'), isFalse,
            reason: 'Protocol must not use camelCase key "targetTemp"');
      }
    });

    test('protocol should handle numeric types correctly', () {
      for (int i = 0; i < iterations; i++) {
        // Generate random values
        final fanSpeed = faker.randomGenerator.integer(101, min: 0);
        final targetTemp = faker.randomGenerator.decimal(scale: 968, min: 32);
        
        // Create command
        final command = IKamandCommand.setBoth(fanSpeed, targetTemp);
        
        // Convert to JSON
        final json = command.toJson();
        
        // Verify types
        expect(json['fan_speed'], isA<int>(),
            reason: 'fan_speed must be an integer');
        expect(json['target_temp'], isA<double>(),
            reason: 'target_temp must be a double');
      }
    });
  });
}
