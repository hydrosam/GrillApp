import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/domain/entities/entities.dart';
import 'package:grill_controller_app/data/repositories/cook_session_repository_impl.dart';
import 'package:grill_controller_app/data/datasources/local_storage_service.dart';
import 'package:grill_controller_app/data/datasources/temperature_database_helper.dart';
import 'package:grill_controller_app/data/models/device_model.dart';
import 'package:grill_controller_app/data/models/cook_session_model.dart';
import 'package:faker/faker.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() {
  group('CookSession Property Tests', () {
    final faker = Faker();
    late CookSessionRepositoryImpl repository;
    late Directory tempDir;

    setUpAll(() async {
      // Initialize sqflite_ffi for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Initialize Hive for testing with a temporary directory
      tempDir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(tempDir.path);
      
      // Register type adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DeviceModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CookSessionModelAdapter());
      }
      
      // Open boxes manually
      await Hive.openBox<DeviceModel>(LocalStorageService.devicesBoxName);
      await Hive.openBox<CookSessionModel>(LocalStorageService.cookSessionsBoxName);
      await Hive.openBox(LocalStorageService.preferencesBoxName);
    });

    setUp(() async {
      repository = CookSessionRepositoryImpl();
      
      // Clear data before each test
      await LocalStorageService.getCookSessionsBox().clear();
      await TemperatureDatabaseHelper.instance.deleteAllReadings();
    });

    tearDownAll(() async {
      await TemperatureDatabaseHelper.instance.close();
      await Hive.close();
      
      // Clean up temp directory
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// Generate a random temperature reading for property testing
    TemperatureReading generateRandomTemperatureReading() {
      // Generate random temperature in valid range (32°F - 700°F)
      final temperature = faker.randomGenerator.decimal(min: 32.0, scale: 700.0);
      
      // Generate random timestamp within the last year
      final now = DateTime.now();
      final randomDaysAgo = faker.randomGenerator.integer(365);
      final timestamp = now.subtract(Duration(days: randomDaysAgo));
      
      // Generate random probe ID (UUID format)
      final probeId = faker.guid.guid();
      
      // Generate random probe type
      final probeTypes = ProbeType.values;
      final type = probeTypes[faker.randomGenerator.integer(probeTypes.length)];
      
      return TemperatureReading(
        probeId: probeId,
        temperature: temperature,
        timestamp: timestamp,
        type: type,
      );
    }

    /// Generate a random cook session for property testing
    Future<CookSession> generateRandomCookSession() async {
      // Generate random device ID
      final deviceId = faker.guid.guid();
      
      // Create session
      final session = await repository.createSession(deviceId);
      
      // Generate random number of temperature readings (0-50)
      final numReadings = faker.randomGenerator.integer(50);
      final readings = List.generate(numReadings, (_) => generateRandomTemperatureReading());
      
      // Add readings to session
      for (final reading in readings) {
        await repository.addReading(session.id, reading);
      }
      
      // Randomly end the session or leave it active
      if (faker.randomGenerator.boolean()) {
        // Generate random notes (50% chance of having notes)
        final notes = faker.randomGenerator.boolean() 
            ? faker.lorem.sentences(faker.randomGenerator.integer(5, min: 1)).join(' ')
            : null;
        
        await repository.endSession(session.id, notes);
      }
      
      // Get the updated session with all data
      return await repository.getSession(session.id);
    }

    test('Property 2: Cook Session Data Round-Trip', () async {
      // **Validates: Requirements 6.2, 6.3, 6.4, 10.1, 10.3**
      // Feature: grill-controller-app, Property 2: Cook session data round-trip
      //
      // For any cook session with notes, temperature history, and cook parameters,
      // persisting the session to local storage and then loading it should produce
      // an equivalent session with all associated data intact.
      
      const iterations = 100;
      int passedIterations = 0;
      
      for (int i = 0; i < iterations; i++) {
        // Generate random cook session with data
        final original = await generateRandomCookSession();
        
        // Retrieve the session from storage
        final retrieved = await repository.getSession(original.id);
        
        // Verify session metadata
        expect(
          retrieved.id,
          equals(original.id),
          reason: 'Session ID should be preserved (iteration $i)',
        );
        
        expect(
          retrieved.deviceId,
          equals(original.deviceId),
          reason: 'Device ID should be preserved (iteration $i)',
        );
        
        expect(
          retrieved.startTime,
          equals(original.startTime),
          reason: 'Start time should be preserved (iteration $i)',
        );
        
        // Verify end time (may be null for active sessions)
        if (original.endTime != null) {
          expect(
            retrieved.endTime,
            isNotNull,
            reason: 'End time should not be null if original had end time (iteration $i)',
          );
          
          // Allow small time difference due to storage precision
          expect(
            retrieved.endTime!.difference(original.endTime!).inSeconds.abs(),
            lessThan(2),
            reason: 'End time should be preserved within 2 seconds (iteration $i)',
          );
        } else {
          expect(
            retrieved.endTime,
            isNull,
            reason: 'End time should be null for active sessions (iteration $i)',
          );
        }
        
        // Verify notes
        expect(
          retrieved.notes,
          equals(original.notes),
          reason: 'Notes should be preserved (iteration $i)',
        );
        
        // Verify temperature readings count
        expect(
          retrieved.readings.length,
          equals(original.readings.length),
          reason: 'Number of temperature readings should match (iteration $i)',
        );
        
        // Verify each temperature reading
        for (int j = 0; j < original.readings.length; j++) {
          final originalReading = original.readings[j];
          final retrievedReading = retrieved.readings[j];
          
          expect(
            retrievedReading.probeId,
            equals(originalReading.probeId),
            reason: 'Reading $j probe ID should match (iteration $i)',
          );
          
          expect(
            retrievedReading.temperature,
            closeTo(originalReading.temperature, 0.01),
            reason: 'Reading $j temperature should match (iteration $i)',
          );
          
          expect(
            retrievedReading.timestamp,
            equals(originalReading.timestamp),
            reason: 'Reading $j timestamp should match (iteration $i)',
          );
          
          expect(
            retrievedReading.type,
            equals(originalReading.type),
            reason: 'Reading $j probe type should match (iteration $i)',
          );
        }
        
        passedIterations++;
        
        // Clean up for next iteration
        await repository.deleteSession(original.id);
      }
      
      // Verify all iterations passed
      expect(passedIterations, equals(iterations),
          reason: 'All $iterations iterations should pass');
    });

    test('Property 2: Cook Session Round-Trip with Edge Cases', () async {
      // Test edge cases that might not be covered by random generation
      
      // Edge case 1: Empty session (no readings, no notes)
      final emptySession = await repository.createSession('device-empty');
      final retrievedEmpty = await repository.getSession(emptySession.id);
      
      expect(retrievedEmpty.id, equals(emptySession.id));
      expect(retrievedEmpty.deviceId, equals('device-empty'));
      expect(retrievedEmpty.readings, isEmpty);
      expect(retrievedEmpty.notes, isNull);
      expect(retrievedEmpty.endTime, isNull);
      
      // Edge case 2: Session with single reading
      final singleReadingSession = await repository.createSession('device-single');
      final singleReading = TemperatureReading(
        probeId: 'probe-1',
        temperature: 250.0,
        timestamp: DateTime.now(),
        type: ProbeType.grill,
      );
      await repository.addReading(singleReadingSession.id, singleReading);
      
      final retrievedSingle = await repository.getSession(singleReadingSession.id);
      expect(retrievedSingle.readings.length, equals(1));
      expect(retrievedSingle.readings.first.probeId, equals('probe-1'));
      
      // Edge case 3: Session with very long notes
      final longNotesSession = await repository.createSession('device-long-notes');
      final longNotes = 'A' * 10000; // 10,000 character notes
      await repository.endSession(longNotesSession.id, longNotes);
      
      final retrievedLongNotes = await repository.getSession(longNotesSession.id);
      expect(retrievedLongNotes.notes, equals(longNotes));
      expect(retrievedLongNotes.notes!.length, equals(10000));
      
      // Edge case 4: Session with empty notes string
      final emptyNotesSession = await repository.createSession('device-empty-notes');
      await repository.endSession(emptyNotesSession.id, '');
      
      final retrievedEmptyNotes = await repository.getSession(emptyNotesSession.id);
      expect(retrievedEmptyNotes.notes, equals(''));
      
      // Edge case 5: Session with many readings (stress test)
      final manyReadingsSession = await repository.createSession('device-many');
      final manyReadings = List.generate(
        1000,
        (i) => TemperatureReading(
          probeId: 'probe-${i % 4}',
          temperature: 200.0 + i * 0.1,
          timestamp: DateTime.now().add(Duration(seconds: i)),
          type: ProbeType.values[i % 4],
        ),
      );
      
      for (final reading in manyReadings) {
        await repository.addReading(manyReadingsSession.id, reading);
      }
      
      final retrievedMany = await repository.getSession(manyReadingsSession.id);
      expect(retrievedMany.readings.length, equals(1000));
      
      // Verify readings are in chronological order
      for (int i = 1; i < retrievedMany.readings.length; i++) {
        expect(
          retrievedMany.readings[i].timestamp.isAfter(retrievedMany.readings[i - 1].timestamp) ||
          retrievedMany.readings[i].timestamp.isAtSameMomentAs(retrievedMany.readings[i - 1].timestamp),
          isTrue,
          reason: 'Readings should be in chronological order',
        );
      }
      
      // Clean up
      await repository.deleteSession(emptySession.id);
      await repository.deleteSession(singleReadingSession.id);
      await repository.deleteSession(longNotesSession.id);
      await repository.deleteSession(emptyNotesSession.id);
      await repository.deleteSession(manyReadingsSession.id);
    });

    test('Property 2: Cook Session Notes Update Preserves Data', () async {
      // Verify that updating notes doesn't corrupt other session data
      
      const iterations = 20;
      
      for (int i = 0; i < iterations; i++) {
        // Create session with readings
        final session = await generateRandomCookSession();
        final originalReadingsCount = session.readings.length;
        
        // Update notes multiple times
        for (int j = 0; j < 5; j++) {
          final newNotes = faker.lorem.sentence();
          await repository.updateNotes(session.id, newNotes);
          
          // Verify notes were updated
          final updated = await repository.getSession(session.id);
          expect(updated.notes, equals(newNotes));
          
          // Verify readings are still intact
          expect(
            updated.readings.length,
            equals(originalReadingsCount),
            reason: 'Readings count should not change when updating notes (iteration $i, update $j)',
          );
          
          // Verify session metadata is intact
          expect(updated.id, equals(session.id));
          expect(updated.deviceId, equals(session.deviceId));
          expect(updated.startTime, equals(session.startTime));
        }
        
        // Clean up
        await repository.deleteSession(session.id);
      }
    });

    test('Property 2: Multiple Sessions for Same Device', () async {
      // Verify that multiple sessions for the same device don't interfere
      
      final deviceId = 'test-device-multi';
      final sessions = <CookSession>[];
      
      // Create multiple sessions for the same device
      for (int i = 0; i < 10; i++) {
        final session = await repository.createSession(deviceId);
        
        // Add some readings
        for (int j = 0; j < 5; j++) {
          await repository.addReading(session.id, generateRandomTemperatureReading());
        }
        
        // End some sessions, leave others active
        if (i % 2 == 0) {
          await repository.endSession(session.id, 'Session $i notes');
        }
        
        sessions.add(await repository.getSession(session.id));
      }
      
      // Verify all sessions can be retrieved correctly
      for (final original in sessions) {
        final retrieved = await repository.getSession(original.id);
        
        expect(retrieved.id, equals(original.id));
        expect(retrieved.deviceId, equals(deviceId));
        expect(retrieved.readings.length, equals(original.readings.length));
        expect(retrieved.notes, equals(original.notes));
      }
      
      // Verify getSessionsForDevice returns all sessions
      final deviceSessions = await repository.getSessionsForDevice(deviceId);
      expect(deviceSessions.length, equals(10));
      
      // Verify getActiveSession returns the most recent active session
      final activeSession = await repository.getActiveSession(deviceId);
      expect(activeSession, isNotNull);
      expect(activeSession!.endTime, isNull);
      
      // Clean up
      for (final session in sessions) {
        await repository.deleteSession(session.id);
      }
    });

    test('Property 2: Session Deletion Removes All Data', () async {
      // Verify that deleting a session removes both metadata and readings
      
      const iterations = 20;
      
      for (int i = 0; i < iterations; i++) {
        // Create session with data
        final session = await generateRandomCookSession();
        final sessionId = session.id;
        
        // Verify session exists
        final beforeDelete = await repository.getSession(sessionId);
        expect(beforeDelete.id, equals(sessionId));
        
        // Delete session
        await repository.deleteSession(sessionId);
        
        // Verify session is gone
        expect(
          () => repository.getSession(sessionId),
          throwsException,
          reason: 'Getting deleted session should throw exception (iteration $i)',
        );
        
        // Verify readings are gone
        final readingsCount = await TemperatureDatabaseHelper.instance
            .getReadingsCountBySession(sessionId);
        expect(
          readingsCount,
          equals(0),
          reason: 'All readings should be deleted (iteration $i)',
        );
      }
    });

    test('Property 2: Cook Session with Special Characters in Notes', () async {
      // Test that special characters in notes are preserved
      
      final specialCharacterNotes = [
        'Notes with "quotes" and \'apostrophes\'',
        'Notes with\nnewlines\nand\ttabs',
        'Notes with emoji 🔥🍖🌡️',
        'Notes with unicode: café, naïve, 日本語',
        'Notes with symbols: @#\$%^&*()_+-=[]{}|;:,.<>?/',
        'Notes with backslashes: C:\\path\\to\\file',
      ];
      
      for (int i = 0; i < specialCharacterNotes.length; i++) {
        final session = await repository.createSession('device-special-$i');
        await repository.endSession(session.id, specialCharacterNotes[i]);
        
        final retrieved = await repository.getSession(session.id);
        expect(
          retrieved.notes,
          equals(specialCharacterNotes[i]),
          reason: 'Special characters should be preserved (case $i)',
        );
        
        await repository.deleteSession(session.id);
      }
    });

    test('Property 2: Cook Session Timestamps Preserve Precision', () async {
      // Verify that timestamps are preserved with millisecond precision
      // Note: SQLite stores timestamps as milliseconds, so microseconds are truncated
      
      final now = DateTime.now();
      final session = await repository.createSession('device-timestamp');
      
      // Add readings with precise timestamps
      // Use only millisecond precision since SQLite truncates microseconds
      final preciseTimestamps = [
        DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch),
        DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch + 1),
        DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch + 100),
        DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch + 999),
      ];
      
      for (final timestamp in preciseTimestamps) {
        final reading = TemperatureReading(
          probeId: 'probe-precise',
          temperature: 250.0,
          timestamp: timestamp,
          type: ProbeType.grill,
        );
        await repository.addReading(session.id, reading);
      }
      
      // Retrieve and verify
      final retrieved = await repository.getSession(session.id);
      
      for (int i = 0; i < preciseTimestamps.length; i++) {
        expect(
          retrieved.readings[i].timestamp.millisecondsSinceEpoch,
          equals(preciseTimestamps[i].millisecondsSinceEpoch),
          reason: 'Timestamp $i should be preserved with millisecond precision',
        );
      }
      
      await repository.deleteSession(session.id);
    });
  });
}
