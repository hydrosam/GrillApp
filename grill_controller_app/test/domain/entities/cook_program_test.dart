import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/domain/entities/entities.dart';

void main() {
  group('CookProgram', () {
    test('should support value equality', () {
      final program1 = CookProgram(
        id: 'prog1',
        name: 'Low and Slow',
        stages: const [
          CookStage(
            targetTemperature: 225.0,
            duration: Duration(hours: 4),
            alertOnComplete: true,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      final program2 = CookProgram(
        id: 'prog1',
        name: 'Low and Slow',
        stages: const [
          CookStage(
            targetTemperature: 225.0,
            duration: Duration(hours: 4),
            alertOnComplete: true,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      expect(program1, equals(program2));
    });

    test('should serialize to JSON correctly', () {
      final program = CookProgram(
        id: 'prog1',
        name: 'Low and Slow',
        stages: const [
          CookStage(
            targetTemperature: 225.0,
            duration: Duration(hours: 4),
            alertOnComplete: true,
          ),
          CookStage(
            targetTemperature: 350.0,
            duration: Duration(hours: 1),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.running,
      );

      final json = program.toJson();

      expect(json['id'], 'prog1');
      expect(json['name'], 'Low and Slow');
      expect(json['status'], 'running');
      expect(json['stages'], isA<List>());
      expect(json['stages'].length, 2);
      expect(json['stages'][0]['targetTemperature'], 225.0);
      expect(json['stages'][0]['duration'], 14400); // 4 hours in seconds
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'prog1',
        'name': 'Low and Slow',
        'stages': [
          {
            'targetTemperature': 225.0,
            'duration': 14400,
            'alertOnComplete': true,
          },
        ],
        'status': 'idle',
      };

      final program = CookProgram.fromJson(json);

      expect(program.id, 'prog1');
      expect(program.name, 'Low and Slow');
      expect(program.status, CookProgramStatus.idle);
      expect(program.stages.length, 1);
      expect(program.stages[0].targetTemperature, 225.0);
      expect(program.stages[0].duration, const Duration(hours: 4));
    });

    test('should round-trip through JSON serialization', () {
      final original = CookProgram(
        id: 'prog1',
        name: 'Low and Slow',
        stages: const [
          CookStage(
            targetTemperature: 225.0,
            duration: Duration(hours: 4),
            alertOnComplete: true,
          ),
          CookStage(
            targetTemperature: 350.0,
            duration: Duration(minutes: 30),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.paused,
      );

      final json = original.toJson();
      final deserialized = CookProgram.fromJson(json);

      expect(deserialized, equals(original));
    });
  });

  group('CookStage', () {
    test('should support value equality', () {
      const stage1 = CookStage(
        targetTemperature: 225.0,
        duration: Duration(hours: 4),
        alertOnComplete: true,
      );

      const stage2 = CookStage(
        targetTemperature: 225.0,
        duration: Duration(hours: 4),
        alertOnComplete: true,
      );

      expect(stage1, equals(stage2));
    });
  });
}
