import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/domain/entities/entities.dart';

void main() {
  group('GrillDevice', () {
    test('should support value equality', () {
      final device1 = GrillDevice(
        id: 'device1',
        name: 'My Grill',
        type: DeviceType.ikamand,
        status: ConnectionStatus.wifi,
        probes: const [],
        fanStatus: FanStatus(
          speed: 50,
          isAutomatic: true,
          lastUpdate: DateTime(2024, 1, 1),
        ),
      );

      final device2 = GrillDevice(
        id: 'device1',
        name: 'My Grill',
        type: DeviceType.ikamand,
        status: ConnectionStatus.wifi,
        probes: const [],
        fanStatus: FanStatus(
          speed: 50,
          isAutomatic: true,
          lastUpdate: DateTime(2024, 1, 1),
        ),
      );

      expect(device1, equals(device2));
    });

    test('should serialize to JSON correctly', () {
      final device = GrillDevice(
        id: 'device1',
        name: 'My Grill',
        type: DeviceType.ikamand,
        status: ConnectionStatus.wifi,
        probes: [
          const Probe(
            id: 'probe1',
            type: ProbeType.grill,
            isActive: true,
            targetTemperature: 250.0,
          ),
        ],
        fanStatus: FanStatus(
          speed: 50,
          isAutomatic: true,
          lastUpdate: DateTime(2024, 1, 1, 12, 0),
        ),
      );

      final json = device.toJson();

      expect(json['id'], 'device1');
      expect(json['name'], 'My Grill');
      expect(json['type'], 'ikamand');
      expect(json['status'], 'wifi');
      expect(json['probes'], isA<List>());
      expect(json['fanStatus'], isA<Map>());
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'device1',
        'name': 'My Grill',
        'type': 'ikamand',
        'status': 'wifi',
        'probes': [
          {
            'id': 'probe1',
            'type': 'grill',
            'isActive': true,
            'targetTemperature': 250.0,
          },
        ],
        'fanStatus': {
          'speed': 50,
          'isAutomatic': true,
          'lastUpdate': '2024-01-01T12:00:00.000',
        },
      };

      final device = GrillDevice.fromJson(json);

      expect(device.id, 'device1');
      expect(device.name, 'My Grill');
      expect(device.type, DeviceType.ikamand);
      expect(device.status, ConnectionStatus.wifi);
      expect(device.probes.length, 1);
      expect(device.fanStatus.speed, 50);
    });

    test('should round-trip through JSON serialization', () {
      final original = GrillDevice(
        id: 'device1',
        name: 'My Grill',
        type: DeviceType.ikamand,
        status: ConnectionStatus.bluetooth,
        probes: [
          const Probe(
            id: 'probe1',
            type: ProbeType.grill,
            isActive: true,
            targetTemperature: 250.0,
          ),
        ],
        fanStatus: FanStatus(
          speed: 75,
          isAutomatic: false,
          lastUpdate: DateTime(2024, 1, 1, 12, 0),
        ),
      );

      final json = original.toJson();
      final deserialized = GrillDevice.fromJson(json);

      expect(deserialized, equals(original));
    });
  });
}
