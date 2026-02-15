import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/domain/entities/entities.dart';

void main() {
  group('CookSession', () {
    test('should support value equality', () {
      final session1 = CookSession(
        id: 'session1',
        startTime: DateTime(2024, 1, 1, 12, 0),
        endTime: DateTime(2024, 1, 1, 16, 0),
        deviceId: 'device1',
        readings: const [],
        notes: 'Great cook!',
        program: null,
      );

      final session2 = CookSession(
        id: 'session1',
        startTime: DateTime(2024, 1, 1, 12, 0),
        endTime: DateTime(2024, 1, 1, 16, 0),
        deviceId: 'device1',
        readings: const [],
        notes: 'Great cook!',
        program: null,
      );

      expect(session1, equals(session2));
    });

    test('should serialize to JSON correctly', () {
      final session = CookSession(
        id: 'session1',
        startTime: DateTime(2024, 1, 1, 12, 0),
        endTime: DateTime(2024, 1, 1, 16, 0),
        deviceId: 'device1',
        readings: [
          TemperatureReading(
            probeId: 'probe1',
            temperature: 250.0,
            timestamp: DateTime(2024, 1, 1, 12, 30),
            type: ProbeType.grill,
          ),
        ],
        notes: 'Great cook!',
        program: null,
      );

      final json = session.toJson();

      expect(json['id'], 'session1');
      expect(json['startTime'], '2024-01-01T12:00:00.000');
      expect(json['endTime'], '2024-01-01T16:00:00.000');
      expect(json['deviceId'], 'device1');
      expect(json['notes'], 'Great cook!');
      expect(json['readings'], isA<List>());
      expect(json['program'], isNull);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'session1',
        'startTime': '2024-01-01T12:00:00.000',
        'endTime': '2024-01-01T16:00:00.000',
        'deviceId': 'device1',
        'readings': [
          {
            'probeId': 'probe1',
            'temperature': 250.0,
            'timestamp': '2024-01-01T12:30:00.000',
            'type': 'grill',
          },
        ],
        'notes': 'Great cook!',
        'program': null,
      };

      final session = CookSession.fromJson(json);

      expect(session.id, 'session1');
      expect(session.startTime, DateTime(2024, 1, 1, 12, 0));
      expect(session.endTime, DateTime(2024, 1, 1, 16, 0));
      expect(session.deviceId, 'device1');
      expect(session.notes, 'Great cook!');
      expect(session.readings.length, 1);
      expect(session.program, isNull);
    });

    test('should round-trip through JSON serialization', () {
      final original = CookSession(
        id: 'session1',
        startTime: DateTime(2024, 1, 1, 12, 0),
        endTime: DateTime(2024, 1, 1, 16, 0),
        deviceId: 'device1',
        readings: [
          TemperatureReading(
            probeId: 'probe1',
            temperature: 250.0,
            timestamp: DateTime(2024, 1, 1, 12, 30),
            type: ProbeType.grill,
          ),
        ],
        notes: 'Great cook!',
        program: CookProgram(
          id: 'prog1',
          name: 'Low and Slow',
          stages: const [
            CookStage(
              targetTemperature: 225.0,
              duration: Duration(hours: 4),
              alertOnComplete: true,
            ),
          ],
          status: CookProgramStatus.completed,
        ),
      );

      final json = original.toJson();
      final deserialized = CookSession.fromJson(json);

      expect(deserialized, equals(original));
    });

    test('should handle null endTime and program', () {
      final session = CookSession(
        id: 'session1',
        startTime: DateTime(2024, 1, 1, 12, 0),
        deviceId: 'device1',
        readings: const [],
      );

      final json = session.toJson();
      final deserialized = CookSession.fromJson(json);

      expect(deserialized.endTime, isNull);
      expect(deserialized.notes, isNull);
      expect(deserialized.program, isNull);
      expect(deserialized, equals(session));
    });
  });
}
