import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:grill_controller_app/data/datasources/local_storage_service.dart';
import 'package:grill_controller_app/data/datasources/temperature_database_helper.dart';
import 'package:grill_controller_app/data/models/cook_session_model.dart';
import 'package:grill_controller_app/data/repositories/cook_session_repository_impl.dart';
import 'package:grill_controller_app/domain/entities/temperature_reading.dart';

/// Mock path provider for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String tempPath;

  MockPathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CookSessionRepository Integration Tests', () {
    late CookSessionRepositoryImpl repository;
    late Directory tempDir;

    setUpAll(() async {
      // Set up mock path provider
      tempDir = await Directory.systemTemp.createTemp('cook_session_test_');
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);

      // Initialize Hive
      await Hive.initFlutter(tempDir.path);
      Hive.registerAdapter(CookSessionModelAdapter());

      // Initialize SQLite with FFI for testing
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      repository = CookSessionRepositoryImpl();
      
      // Open boxes if not already open
      await LocalStorageService.openBoxes();
      
      // Clear data before each test
      await LocalStorageService.clearAllData();
      await TemperatureDatabaseHelper.instance.deleteAllReadings();
    });

    tearDownAll(() async {
      await LocalStorageService.closeBoxes();
      await TemperatureDatabaseHelper.instance.close();
      
      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Complete CRUD workflow - create, read, update, delete session', () async {
      // Requirement 6.1: Create session
      final session = await repository.createSession('device-123');
      
      expect(session.id, isNotEmpty);
      expect(session.deviceId, equals('device-123'));
      expect(session.startTime, isNotNull);
      expect(session.endTime, isNull);
      expect(session.readings, isEmpty);
      expect(session.notes, isNull);

      // Add some temperature readings
      final reading1 = TemperatureReading(
        probeId: 'probe-1',
        temperature: 225.0,
        timestamp: DateTime.now(),
        type: ProbeType.grill,
      );
      final reading2 = TemperatureReading(
        probeId: 'probe-2',
        temperature: 165.0,
        timestamp: DateTime.now().add(const Duration(minutes: 1)),
        type: ProbeType.food1,
      );

      await repository.addReading(session.id, reading1);
      await repository.addReading(session.id, reading2);

      // Requirement 6.3: Read session with temperature history
      final retrievedSession = await repository.getSession(session.id);
      expect(retrievedSession.id, equals(session.id));
      expect(retrievedSession.readings.length, equals(2));
      expect(retrievedSession.readings[0].temperature, equals(225.0));
      expect(retrievedSession.readings[1].temperature, equals(165.0));

      // Requirement 6.1, 6.5: Update notes
      await repository.updateNotes(session.id, 'Great cook! Brisket turned out perfect.');
      
      final sessionWithNotes = await repository.getSession(session.id);
      expect(sessionWithNotes.notes, equals('Great cook! Brisket turned out perfect.'));

      // Requirement 6.2: End session with notes
      await repository.endSession(session.id, 'Final notes: 12 hours total cook time');
      
      final endedSession = await repository.getSession(session.id);
      expect(endedSession.endTime, isNotNull);
      expect(endedSession.notes, equals('Final notes: 12 hours total cook time'));

      // Requirement 6.3: Get all sessions
      final allSessions = await repository.getAllSessions();
      expect(allSessions.length, equals(1));
      expect(allSessions[0].id, equals(session.id));

      // Requirement 6.5: Delete session
      await repository.deleteSession(session.id);
      
      // Verify deletion
      expect(
        () => repository.getSession(session.id),
        throwsException,
      );
      
      final sessionsAfterDelete = await repository.getAllSessions();
      expect(sessionsAfterDelete, isEmpty);
    });

    test('Requirement 6.4: Sessions link with temperature readings correctly', () async {
      // Create session
      final session = await repository.createSession('device-456');
      
      // Add multiple temperature readings
      final readings = List.generate(10, (i) => TemperatureReading(
        probeId: 'probe-grill',
        temperature: 200.0 + i * 5,
        timestamp: DateTime.now().add(Duration(minutes: i)),
        type: ProbeType.grill,
      ));

      for (final reading in readings) {
        await repository.addReading(session.id, reading);
      }

      // Retrieve session and verify all readings are linked
      final retrievedSession = await repository.getSession(session.id);
      expect(retrievedSession.readings.length, equals(10));
      
      // Verify readings are in chronological order
      for (int i = 0; i < retrievedSession.readings.length - 1; i++) {
        expect(
          retrievedSession.readings[i].timestamp.isBefore(
            retrievedSession.readings[i + 1].timestamp,
          ),
          isTrue,
        );
      }
      
      // Verify temperature values
      for (int i = 0; i < retrievedSession.readings.length; i++) {
        expect(retrievedSession.readings[i].temperature, equals(200.0 + i * 5));
      }
    });

    test('Multiple sessions for same device are tracked separately', () async {
      // Create multiple sessions for same device
      final session1 = await repository.createSession('device-789');
      await Future.delayed(const Duration(milliseconds: 10));
      final session2 = await repository.createSession('device-789');
      await Future.delayed(const Duration(milliseconds: 10));
      final session3 = await repository.createSession('device-789');

      // Add readings to each session
      await repository.addReading(session1.id, TemperatureReading(
        probeId: 'probe-1',
        temperature: 225.0,
        timestamp: DateTime.now(),
        type: ProbeType.grill,
      ));
      
      await repository.addReading(session2.id, TemperatureReading(
        probeId: 'probe-1',
        temperature: 250.0,
        timestamp: DateTime.now(),
        type: ProbeType.grill,
      ));

      // End first session
      await repository.endSession(session1.id, 'Session 1 notes');

      // Get sessions for device
      final deviceSessions = await repository.getSessionsForDevice('device-789');
      expect(deviceSessions.length, equals(3));

      // Verify sessions are sorted by start time (most recent first)
      expect(deviceSessions[0].id, equals(session3.id));
      expect(deviceSessions[1].id, equals(session2.id));
      expect(deviceSessions[2].id, equals(session1.id));

      // Get active session (should be session3 or session2, not session1)
      final activeSession = await repository.getActiveSession('device-789');
      expect(activeSession, isNotNull);
      expect(activeSession!.endTime, isNull);
      expect(activeSession.id, isNot(equals(session1.id)));
    });

    test('Session stream emits updates when readings are added', () async {
      final session = await repository.createSession('device-stream');
      
      // Watch the session
      final streamFuture = repository.watchSession(session.id).take(2).toList();

      // Add readings
      await repository.addReading(session.id, TemperatureReading(
        probeId: 'probe-1',
        temperature: 225.0,
        timestamp: DateTime.now(),
        type: ProbeType.grill,
      ));

      await repository.addReading(session.id, TemperatureReading(
        probeId: 'probe-1',
        temperature: 230.0,
        timestamp: DateTime.now().add(const Duration(seconds: 30)),
        type: ProbeType.grill,
      ));

      // Wait for stream updates
      final updates = await streamFuture;
      expect(updates.length, equals(2));
      expect(updates[0].readings.length, equals(1));
      expect(updates[1].readings.length, equals(2));
    });
  });
}
