import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/data/datasources/temperature_database_helper.dart';
import 'package:grill_controller_app/domain/entities/temperature_reading.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late TemperatureDatabaseHelper dbHelper;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = TemperatureDatabaseHelper.instance;
    // Clear any existing data
    await dbHelper.deleteAllReadings();
  });

  tearDown(() async {
    await dbHelper.deleteAllReadings();
  });

  group('TemperatureDatabaseHelper', () {
    test('should insert and retrieve a temperature reading', () async {
      // Arrange
      final reading = TemperatureReading(
        probeId: 'probe1',
        temperature: 225.5,
        timestamp: DateTime.now(),
        type: ProbeType.grill,
      );
      const sessionId = 'session1';

      // Act
      final id = await dbHelper.insertReading(reading, sessionId);
      final retrieved = await dbHelper.getReading(id);

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.probeId, equals(reading.probeId));
      expect(retrieved.temperature, equals(reading.temperature));
      expect(retrieved.type, equals(reading.type));
      expect(
        retrieved.timestamp.millisecondsSinceEpoch,
        equals(reading.timestamp.millisecondsSinceEpoch),
      );
    });

    test('should insert multiple readings in batch', () async {
      // Arrange
      final readings = [
        TemperatureReading(
          probeId: 'probe1',
          temperature: 225.0,
          timestamp: DateTime.now(),
          type: ProbeType.grill,
        ),
        TemperatureReading(
          probeId: 'probe2',
          temperature: 165.0,
          timestamp: DateTime.now(),
          type: ProbeType.food1,
        ),
      ];
      const sessionId = 'session1';

      // Act
      final ids = await dbHelper.insertReadings(readings, sessionId);

      // Assert
      expect(ids.length, equals(2));
      final count = await dbHelper.getReadingsCountBySession(sessionId);
      expect(count, equals(2));
    });

    test('should retrieve readings by session', () async {
      // Arrange
      final reading1 = TemperatureReading(
        probeId: 'probe1',
        temperature: 225.0,
        timestamp: DateTime.now(),
        type: ProbeType.grill,
      );
      final reading2 = TemperatureReading(
        probeId: 'probe1',
        temperature: 230.0,
        timestamp: DateTime.now().add(const Duration(minutes: 1)),
        type: ProbeType.grill,
      );
      const sessionId = 'session1';

      // Act
      await dbHelper.insertReading(reading1, sessionId);
      await dbHelper.insertReading(reading2, sessionId);
      final retrieved = await dbHelper.getReadingsBySession(sessionId);

      // Assert
      expect(retrieved.length, equals(2));
      expect(retrieved[0].temperature, equals(225.0));
      expect(retrieved[1].temperature, equals(230.0));
    });

    test('should retrieve readings by time range', () async {
      // Arrange
      final now = DateTime.now();
      final reading1 = TemperatureReading(
        probeId: 'probe1',
        temperature: 225.0,
        timestamp: now,
        type: ProbeType.grill,
      );
      final reading2 = TemperatureReading(
        probeId: 'probe1',
        temperature: 230.0,
        timestamp: now.add(const Duration(minutes: 5)),
        type: ProbeType.grill,
      );
      final reading3 = TemperatureReading(
        probeId: 'probe1',
        temperature: 235.0,
        timestamp: now.add(const Duration(minutes: 10)),
        type: ProbeType.grill,
      );
      const sessionId = 'session1';

      // Act
      await dbHelper.insertReading(reading1, sessionId);
      await dbHelper.insertReading(reading2, sessionId);
      await dbHelper.insertReading(reading3, sessionId);

      final retrieved = await dbHelper.getReadingsByTimeRange(
        now.subtract(const Duration(minutes: 1)),
        now.add(const Duration(minutes: 6)),
      );

      // Assert
      expect(retrieved.length, equals(2));
      expect(retrieved[0].temperature, equals(225.0));
      expect(retrieved[1].temperature, equals(230.0));
    });

    test('should retrieve latest reading for probe', () async {
      // Arrange
      final now = DateTime.now();
      final reading1 = TemperatureReading(
        probeId: 'probe1',
        temperature: 225.0,
        timestamp: now,
        type: ProbeType.grill,
      );
      final reading2 = TemperatureReading(
        probeId: 'probe1',
        temperature: 230.0,
        timestamp: now.add(const Duration(minutes: 1)),
        type: ProbeType.grill,
      );
      const sessionId = 'session1';

      // Act
      await dbHelper.insertReading(reading1, sessionId);
      await dbHelper.insertReading(reading2, sessionId);
      final latest = await dbHelper.getLatestReadingForProbe('probe1');

      // Assert
      expect(latest, isNotNull);
      expect(latest!.temperature, equals(230.0));
    });

    test('should delete readings by session', () async {
      // Arrange
      final reading = TemperatureReading(
        probeId: 'probe1',
        temperature: 225.0,
        timestamp: DateTime.now(),
        type: ProbeType.grill,
      );
      const sessionId = 'session1';

      // Act
      await dbHelper.insertReading(reading, sessionId);
      final countBefore = await dbHelper.getReadingsCountBySession(sessionId);
      await dbHelper.deleteReadingsBySession(sessionId);
      final countAfter = await dbHelper.getReadingsCountBySession(sessionId);

      // Assert
      expect(countBefore, equals(1));
      expect(countAfter, equals(0));
    });

    test('should delete readings older than date', () async {
      // Arrange
      final now = DateTime.now();
      final oldReading = TemperatureReading(
        probeId: 'probe1',
        temperature: 225.0,
        timestamp: now.subtract(const Duration(days: 2)),
        type: ProbeType.grill,
      );
      final newReading = TemperatureReading(
        probeId: 'probe1',
        temperature: 230.0,
        timestamp: now,
        type: ProbeType.grill,
      );
      const sessionId = 'session1';

      // Act
      await dbHelper.insertReading(oldReading, sessionId);
      await dbHelper.insertReading(newReading, sessionId);
      await dbHelper.deleteReadingsOlderThan(
        now.subtract(const Duration(days: 1)),
      );
      final remaining = await dbHelper.getReadingsBySession(sessionId);

      // Assert
      expect(remaining.length, equals(1));
      expect(remaining[0].temperature, equals(230.0));
    });

    test('should handle queries with indexes efficiently', () async {
      // Arrange - Insert many readings to test index performance
      final readings = <TemperatureReading>[];
      final now = DateTime.now();
      const sessionId = 'session1';

      for (int i = 0; i < 100; i++) {
        readings.add(
          TemperatureReading(
            probeId: 'probe1',
            temperature: 200.0 + i,
            timestamp: now.add(Duration(minutes: i)),
            type: ProbeType.grill,
          ),
        );
      }

      // Act
      await dbHelper.insertReadings(readings, sessionId);
      final startTime = DateTime.now();
      final retrieved = await dbHelper.getReadingsBySessionAndTimeRange(
        sessionId,
        now,
        now.add(const Duration(minutes: 50)),
      );
      final endTime = DateTime.now();
      final queryDuration = endTime.difference(startTime);

      // Assert
      expect(retrieved.length, equals(51)); // 0 to 50 inclusive
      expect(queryDuration.inMilliseconds, lessThan(100)); // Should be fast
    });
  });
}
