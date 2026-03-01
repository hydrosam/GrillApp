import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:grill_controller_app/data/repositories/temperature_repository_impl.dart';
import 'package:grill_controller_app/data/datasources/temperature_database_helper.dart';
import 'package:grill_controller_app/data/datasources/ikamand_http_service.dart';
import 'package:grill_controller_app/domain/entities/temperature_reading.dart';
import 'package:grill_controller_app/data/models/ikamand_status.dart';

// Mock classes
class MockTemperatureDatabaseHelper extends Mock implements TemperatureDatabaseHelper {}
class MockIKamandHttpService extends Mock implements IKamandHttpService {}

void main() {
  late TemperatureRepositoryImpl repository;
  late MockTemperatureDatabaseHelper mockDatabaseHelper;
  late MockIKamandHttpService mockHttpService;

  setUp(() {
    mockDatabaseHelper = MockTemperatureDatabaseHelper();
    mockHttpService = MockIKamandHttpService();

    repository = TemperatureRepositoryImpl(
      databaseHelper: mockDatabaseHelper,
      httpService: mockHttpService,
    );
  });

  tearDown(() {
    repository.dispose();
  });

  group('TemperatureRepository - Save Reading', () {
    test('saveReading saves temperature reading to database', () async {
      // Arrange
      final reading = TemperatureReading(
        probeId: 'device1_grill',
        temperature: 250.0,
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: ProbeType.grill,
      );

      when(() => mockDatabaseHelper.insertReading(reading, any()))
          .thenAnswer((_) async => 'reading-id-1');

      // Act
      await repository.saveReading(reading);

      // Assert
      verify(() => mockDatabaseHelper.insertReading(reading, any())).called(1);
    });

    test('saveReading throws exception on database failure', () async {
      // Arrange
      final reading = TemperatureReading(
        probeId: 'device1_grill',
        temperature: 250.0,
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: ProbeType.grill,
      );

      when(() => mockDatabaseHelper.insertReading(reading, any()))
          .thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => repository.saveReading(reading),
        throwsException,
      );
    });
  });

  group('TemperatureRepository - Get History', () {
    test('getHistory returns readings for device in time range', () async {
      // Arrange
      const deviceId = 'device1';
      final start = DateTime(2024, 1, 1, 10, 0);
      final end = DateTime(2024, 1, 1, 12, 0);

      final expectedReadings = [
        TemperatureReading(
          probeId: 'device1_grill',
          temperature: 250.0,
          timestamp: DateTime(2024, 1, 1, 11, 0),
          type: ProbeType.grill,
        ),
        TemperatureReading(
          probeId: 'device1_food1',
          temperature: 165.0,
          timestamp: DateTime(2024, 1, 1, 11, 0),
          type: ProbeType.food1,
        ),
      ];

      when(() => mockDatabaseHelper.getReadingsByTimeRange(start, end))
          .thenAnswer((_) async => expectedReadings);

      // Act
      final readings = await repository.getHistory(deviceId, start, end);

      // Assert
      expect(readings, expectedReadings);
      verify(() => mockDatabaseHelper.getReadingsByTimeRange(start, end)).called(1);
    });

    test('getHistory filters readings by device ID', () async {
      // Arrange
      const deviceId = 'device1';
      final start = DateTime(2024, 1, 1, 10, 0);
      final end = DateTime(2024, 1, 1, 12, 0);

      final allReadings = [
        TemperatureReading(
          probeId: 'device1_grill',
          temperature: 250.0,
          timestamp: DateTime(2024, 1, 1, 11, 0),
          type: ProbeType.grill,
        ),
        TemperatureReading(
          probeId: 'device2_grill',
          temperature: 300.0,
          timestamp: DateTime(2024, 1, 1, 11, 0),
          type: ProbeType.grill,
        ),
      ];

      when(() => mockDatabaseHelper.getReadingsByTimeRange(start, end))
          .thenAnswer((_) async => allReadings);

      // Act
      final readings = await repository.getHistory(deviceId, start, end);

      // Assert
      expect(readings.length, 1);
      expect(readings[0].probeId, 'device1_grill');
    });

    test('getHistory throws exception on database failure', () async {
      // Arrange
      const deviceId = 'device1';
      final start = DateTime(2024, 1, 1, 10, 0);
      final end = DateTime(2024, 1, 1, 12, 0);

      when(() => mockDatabaseHelper.getReadingsByTimeRange(start, end))
          .thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => repository.getHistory(deviceId, start, end),
        throwsException,
      );
    });
  });

  group('TemperatureRepository - Get Session History', () {
    test('getSessionHistory returns readings for session', () async {
      // Arrange
      const sessionId = 'session1';

      final expectedReadings = [
        TemperatureReading(
          probeId: 'device1_grill',
          temperature: 250.0,
          timestamp: DateTime(2024, 1, 1, 11, 0),
          type: ProbeType.grill,
        ),
      ];

      when(() => mockDatabaseHelper.getReadingsBySession(sessionId))
          .thenAnswer((_) async => expectedReadings);

      // Act
      final readings = await repository.getSessionHistory(sessionId);

      // Assert
      expect(readings, expectedReadings);
      verify(() => mockDatabaseHelper.getReadingsBySession(sessionId)).called(1);
    });

    test('getSessionHistory throws exception on database failure', () async {
      // Arrange
      const sessionId = 'session1';

      when(() => mockDatabaseHelper.getReadingsBySession(sessionId))
          .thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => repository.getSessionHistory(sessionId),
        throwsException,
      );
    });
  });

  group('TemperatureRepository - Delete Old Readings', () {
    test('deleteOldReadings deletes readings before date', () async {
      // Arrange
      final before = DateTime(2024, 1, 1);

      when(() => mockDatabaseHelper.deleteReadingsOlderThan(before))
          .thenAnswer((_) async => 10);

      // Act
      await repository.deleteOldReadings(before);

      // Assert
      verify(() => mockDatabaseHelper.deleteReadingsOlderThan(before)).called(1);
    });

    test('deleteOldReadings throws exception on database failure', () async {
      // Arrange
      final before = DateTime(2024, 1, 1);

      when(() => mockDatabaseHelper.deleteReadingsOlderThan(before))
          .thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => repository.deleteOldReadings(before),
        throwsException,
      );
    });
  });

  group('TemperatureRepository - Get Latest Reading', () {
    test('getLatestReading returns latest reading for probe', () async {
      // Arrange
      const deviceId = 'device1';
      const probeType = ProbeType.grill;
      const probeId = 'device1_grill';

      final expectedReading = TemperatureReading(
        probeId: probeId,
        temperature: 250.0,
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: probeType,
      );

      when(() => mockDatabaseHelper.getLatestReadingForProbe(probeId))
          .thenAnswer((_) async => expectedReading);

      // Act
      final reading = await repository.getLatestReading(deviceId, probeType);

      // Assert
      expect(reading, expectedReading);
      verify(() => mockDatabaseHelper.getLatestReadingForProbe(probeId)).called(1);
    });

    test('getLatestReading returns null when no reading exists', () async {
      // Arrange
      const deviceId = 'device1';
      const probeType = ProbeType.grill;
      const probeId = 'device1_grill';

      when(() => mockDatabaseHelper.getLatestReadingForProbe(probeId))
          .thenAnswer((_) async => null);

      // Act
      final reading = await repository.getLatestReading(deviceId, probeType);

      // Assert
      expect(reading, isNull);
    });

    test('getLatestReading throws exception on database failure', () async {
      // Arrange
      const deviceId = 'device1';
      const probeType = ProbeType.grill;
      const probeId = 'device1_grill';

      when(() => mockDatabaseHelper.getLatestReadingForProbe(probeId))
          .thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => repository.getLatestReading(deviceId, probeType),
        throwsException,
      );
    });
  });

  group('TemperatureRepository - Active Session Management', () {
    test('setActiveSession stores session ID for device', () {
      // Arrange
      const deviceId = 'device1';
      const sessionId = 'session1';

      // Act
      repository.setActiveSession(deviceId, sessionId);

      // Assert
      expect(repository.getActiveSession(deviceId), sessionId);
    });

    test('setActiveSession can clear session by passing null', () {
      // Arrange
      const deviceId = 'device1';
      repository.setActiveSession(deviceId, 'session1');

      // Act
      repository.setActiveSession(deviceId, null);

      // Assert
      expect(repository.getActiveSession(deviceId), isNull);
    });

    test('getActiveSession returns null for device without session', () {
      // Arrange
      const deviceId = 'device1';

      // Act
      final sessionId = repository.getActiveSession(deviceId);

      // Assert
      expect(sessionId, isNull);
    });
  });

  group('TemperatureRepository - Stop Watching', () {
    test('stopWatching cleans up resources for device', () {
      // Arrange
      const deviceId = 'device1';
      repository.setActiveSession(deviceId, 'session1');

      // Act
      repository.stopWatching(deviceId);

      // Assert
      expect(repository.getActiveSession(deviceId), isNull);
    });
  });
}
