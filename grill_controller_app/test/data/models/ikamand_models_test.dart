import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/data/models/ikamand_status.dart';
import 'package:grill_controller_app/data/models/ikamand_command.dart';

void main() {
  group('IKamandStatus', () {
    group('fromJson', () {
      test('should parse complete status with all probes', () {
        // Arrange
        final json = {
          'grill_temp': 250.5,
          'food1_temp': 165.0,
          'food2_temp': 155.0,
          'food3_temp': 145.0,
          'fan_speed': 45,
          'target_temp': 275.0,
        };

        // Act
        final status = IKamandStatus.fromJson(json);

        // Assert
        expect(status.grillTemp, 250.5);
        expect(status.food1Temp, 165.0);
        expect(status.food2Temp, 155.0);
        expect(status.food3Temp, 145.0);
        expect(status.fanSpeed, 45);
        expect(status.targetTemp, 275.0);
      });

      test('should parse status with null food probes', () {
        // Arrange
        final json = {
          'grill_temp': 300.0,
          'food1_temp': null,
          'food2_temp': null,
          'food3_temp': null,
          'fan_speed': 60,
          'target_temp': 325.0,
        };

        // Act
        final status = IKamandStatus.fromJson(json);

        // Assert
        expect(status.grillTemp, 300.0);
        expect(status.food1Temp, null);
        expect(status.food2Temp, null);
        expect(status.food3Temp, null);
        expect(status.fanSpeed, 60);
        expect(status.targetTemp, 325.0);
      });

      test('should parse status with some food probes active', () {
        // Arrange
        final json = {
          'grill_temp': 225.0,
          'food1_temp': 150.0,
          'food2_temp': null,
          'food3_temp': 160.0,
          'fan_speed': 30,
          'target_temp': 250.0,
        };

        // Act
        final status = IKamandStatus.fromJson(json);

        // Assert
        expect(status.grillTemp, 225.0);
        expect(status.food1Temp, 150.0);
        expect(status.food2Temp, null);
        expect(status.food3Temp, 160.0);
        expect(status.fanSpeed, 30);
        expect(status.targetTemp, 250.0);
      });

      test('should handle integer temperatures', () {
        // Arrange
        final json = {
          'grill_temp': 250,
          'food1_temp': 165,
          'food2_temp': null,
          'food3_temp': null,
          'fan_speed': 45,
          'target_temp': 275,
        };

        // Act
        final status = IKamandStatus.fromJson(json);

        // Assert
        expect(status.grillTemp, 250.0);
        expect(status.food1Temp, 165.0);
        expect(status.targetTemp, 275.0);
      });
    });

    group('toJson', () {
      test('should serialize status with all probes', () {
        // Arrange
        const status = IKamandStatus(
          grillTemp: 250.5,
          food1Temp: 165.0,
          food2Temp: 155.0,
          food3Temp: 145.0,
          fanSpeed: 45,
          targetTemp: 275.0,
        );

        // Act
        final json = status.toJson();

        // Assert
        expect(json['grill_temp'], 250.5);
        expect(json['food1_temp'], 165.0);
        expect(json['food2_temp'], 155.0);
        expect(json['food3_temp'], 145.0);
        expect(json['fan_speed'], 45);
        expect(json['target_temp'], 275.0);
      });

      test('should serialize status with null food probes', () {
        // Arrange
        const status = IKamandStatus(
          grillTemp: 300.0,
          food1Temp: null,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: 60,
          targetTemp: 325.0,
        );

        // Act
        final json = status.toJson();

        // Assert
        expect(json['grill_temp'], 300.0);
        expect(json['food1_temp'], null);
        expect(json['food2_temp'], null);
        expect(json['food3_temp'], null);
        expect(json['fan_speed'], 60);
        expect(json['target_temp'], 325.0);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        // Arrange
        const status1 = IKamandStatus(
          grillTemp: 250.0,
          food1Temp: 165.0,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: 45,
          targetTemp: 275.0,
        );

        const status2 = IKamandStatus(
          grillTemp: 250.0,
          food1Temp: 165.0,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: 45,
          targetTemp: 275.0,
        );

        // Assert
        expect(status1, equals(status2));
      });

      test('should not be equal when fields differ', () {
        // Arrange
        const status1 = IKamandStatus(
          grillTemp: 250.0,
          food1Temp: 165.0,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: 45,
          targetTemp: 275.0,
        );

        const status2 = IKamandStatus(
          grillTemp: 251.0, // Different
          food1Temp: 165.0,
          food2Temp: null,
          food3Temp: null,
          fanSpeed: 45,
          targetTemp: 275.0,
        );

        // Assert
        expect(status1, isNot(equals(status2)));
      });
    });
  });

  group('IKamandCommand', () {
    group('factory constructors', () {
      test('setFanSpeed should create command with only fan speed', () {
        // Act
        final command = IKamandCommand.setFanSpeed(50);

        // Assert
        expect(command.fanSpeed, 50);
        expect(command.targetTemp, null);
      });

      test('setTargetTemp should create command with only target temp', () {
        // Act
        final command = IKamandCommand.setTargetTemp(275.0);

        // Assert
        expect(command.fanSpeed, null);
        expect(command.targetTemp, 275.0);
      });

      test('setBoth should create command with both values', () {
        // Act
        final command = IKamandCommand.setBoth(60, 300.0);

        // Assert
        expect(command.fanSpeed, 60);
        expect(command.targetTemp, 300.0);
      });

      test('setFanSpeed should assert valid range', () {
        // Assert
        expect(() => IKamandCommand.setFanSpeed(-1), throwsA(isA<AssertionError>()));
        expect(() => IKamandCommand.setFanSpeed(101), throwsA(isA<AssertionError>()));
        expect(() => IKamandCommand.setFanSpeed(0), returnsNormally);
        expect(() => IKamandCommand.setFanSpeed(100), returnsNormally);
      });

      test('setTargetTemp should assert valid range', () {
        // Assert
        expect(() => IKamandCommand.setTargetTemp(31.0), throwsA(isA<AssertionError>()));
        expect(() => IKamandCommand.setTargetTemp(1001.0), throwsA(isA<AssertionError>()));
        expect(() => IKamandCommand.setTargetTemp(32.0), returnsNormally);
        expect(() => IKamandCommand.setTargetTemp(1000.0), returnsNormally);
      });
    });

    group('toJson', () {
      test('should serialize command with only fan speed', () {
        // Arrange
        final command = IKamandCommand.setFanSpeed(50);

        // Act
        final json = command.toJson();

        // Assert
        expect(json['fan_speed'], 50);
        expect(json.containsKey('target_temp'), false);
      });

      test('should serialize command with only target temp', () {
        // Arrange
        final command = IKamandCommand.setTargetTemp(275.0);

        // Act
        final json = command.toJson();

        // Assert
        expect(json['target_temp'], 275.0);
        expect(json.containsKey('fan_speed'), false);
      });

      test('should serialize command with both values', () {
        // Arrange
        final command = IKamandCommand.setBoth(60, 300.0);

        // Act
        final json = command.toJson();

        // Assert
        expect(json['fan_speed'], 60);
        expect(json['target_temp'], 300.0);
      });

      test('should serialize empty command', () {
        // Arrange
        const command = IKamandCommand();

        // Act
        final json = command.toJson();

        // Assert
        expect(json.isEmpty, true);
      });
    });

    group('fromJson', () {
      test('should parse command with both values', () {
        // Arrange
        final json = {
          'fan_speed': 50,
          'target_temp': 275.0,
        };

        // Act
        final command = IKamandCommand.fromJson(json);

        // Assert
        expect(command.fanSpeed, 50);
        expect(command.targetTemp, 275.0);
      });

      test('should parse command with only fan speed', () {
        // Arrange
        final json = {
          'fan_speed': 50,
        };

        // Act
        final command = IKamandCommand.fromJson(json);

        // Assert
        expect(command.fanSpeed, 50);
        expect(command.targetTemp, null);
      });

      test('should parse command with only target temp', () {
        // Arrange
        final json = {
          'target_temp': 275.0,
        };

        // Act
        final command = IKamandCommand.fromJson(json);

        // Assert
        expect(command.fanSpeed, null);
        expect(command.targetTemp, 275.0);
      });

      test('should parse empty command', () {
        // Arrange
        final json = <String, dynamic>{};

        // Act
        final command = IKamandCommand.fromJson(json);

        // Assert
        expect(command.fanSpeed, null);
        expect(command.targetTemp, null);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        // Arrange
        const command1 = IKamandCommand(fanSpeed: 50, targetTemp: 275.0);
        const command2 = IKamandCommand(fanSpeed: 50, targetTemp: 275.0);

        // Assert
        expect(command1, equals(command2));
      });

      test('should not be equal when fields differ', () {
        // Arrange
        const command1 = IKamandCommand(fanSpeed: 50, targetTemp: 275.0);
        const command2 = IKamandCommand(fanSpeed: 60, targetTemp: 275.0);

        // Assert
        expect(command1, isNot(equals(command2)));
      });
    });
  });
}
