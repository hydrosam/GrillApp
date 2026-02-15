import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/domain/entities/entities.dart';

void main() {
  group('TemperatureReading', () {
    test('should support value equality', () {
      final reading1 = TemperatureReading(
        probeId: 'probe1',
        temperature: 250.0,
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: ProbeType.grill,
      );

      final reading2 = TemperatureReading(
        probeId: 'probe1',
        temperature: 250.0,
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: ProbeType.grill,
      );

      expect(reading1, equals(reading2));
    });

    test('should serialize to JSON correctly', () {
      final reading = TemperatureReading(
        probeId: 'probe1',
        temperature: 250.5,
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: ProbeType.grill,
      );

      final json = reading.toJson();

      expect(json['probeId'], 'probe1');
      expect(json['temperature'], 250.5);
      expect(json['timestamp'], '2024-01-01T12:00:00.000');
      expect(json['type'], 'grill');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'probeId': 'probe1',
        'temperature': 250.5,
        'timestamp': '2024-01-01T12:00:00.000',
        'type': 'grill',
      };

      final reading = TemperatureReading.fromJson(json);

      expect(reading.probeId, 'probe1');
      expect(reading.temperature, 250.5);
      expect(reading.timestamp, DateTime(2024, 1, 1, 12, 0));
      expect(reading.type, ProbeType.grill);
    });

    test('should round-trip through JSON serialization', () {
      final original = TemperatureReading(
        probeId: 'probe1',
        temperature: 250.5,
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: ProbeType.food1,
      );

      final json = original.toJson();
      final deserialized = TemperatureReading.fromJson(json);

      expect(deserialized, equals(original));
    });
  });
}
