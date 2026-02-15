import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/entities/cook_session.dart';
import '../../domain/entities/temperature_reading.dart';
import '../../domain/repositories/cook_session_repository.dart';
import '../datasources/local_storage_service.dart';
import '../datasources/temperature_database_helper.dart';
import '../models/cook_session_model.dart';

/// Implementation of CookSessionRepository using Hive and SQLite
/// 
/// Cook session metadata is stored in Hive for quick access,
/// while temperature readings are stored in SQLite for efficient
/// time-series queries.
class CookSessionRepositoryImpl implements CookSessionRepository {
  final _uuid = const Uuid();
  final _sessionStreamControllers = <String, StreamController<CookSession>>{};

  @override
  Future<CookSession> createSession(String deviceId) async {
    final sessionId = _uuid.v4();
    final now = DateTime.now();

    // Create session model for Hive
    final sessionModel = CookSessionModel(
      id: sessionId,
      startTime: now,
      deviceId: deviceId,
    );

    // Save to Hive
    final box = LocalStorageService.getCookSessionsBox();
    await box.put(sessionId, sessionModel);

    // Return domain entity
    return CookSession(
      id: sessionId,
      startTime: now,
      deviceId: deviceId,
      readings: [],
    );
  }

  @override
  Future<void> endSession(String sessionId, String? notes) async {
    final box = LocalStorageService.getCookSessionsBox();
    final sessionModel = box.get(sessionId);

    if (sessionModel == null) {
      throw Exception('Session not found: $sessionId');
    }

    // Update session with end time and notes
    sessionModel.endTime = DateTime.now();
    sessionModel.notes = notes;

    // Save back to Hive
    await sessionModel.save();
  }

  @override
  Future<CookSession> getSession(String sessionId) async {
    final box = LocalStorageService.getCookSessionsBox();
    final sessionModel = box.get(sessionId);

    if (sessionModel == null) {
      throw Exception('Session not found: $sessionId');
    }

    // Get temperature readings from SQLite
    final readings = await TemperatureDatabaseHelper.instance
        .getReadingsBySession(sessionId);

    // Convert to domain entity
    return CookSession(
      id: sessionModel.id,
      startTime: sessionModel.startTime,
      endTime: sessionModel.endTime,
      deviceId: sessionModel.deviceId,
      readings: readings,
      notes: sessionModel.notes,
      program: null, // TODO: Load program if programId is set
    );
  }

  @override
  Future<List<CookSession>> getAllSessions() async {
    final box = LocalStorageService.getCookSessionsBox();
    final sessionModels = box.values.toList();

    // Sort by start time (most recent first)
    sessionModels.sort((a, b) => b.startTime.compareTo(a.startTime));

    // Convert to domain entities
    final sessions = <CookSession>[];
    for (final model in sessionModels) {
      final readings = await TemperatureDatabaseHelper.instance
          .getReadingsBySession(model.id);

      sessions.add(CookSession(
        id: model.id,
        startTime: model.startTime,
        endTime: model.endTime,
        deviceId: model.deviceId,
        readings: readings,
        notes: model.notes,
        program: null, // TODO: Load program if programId is set
      ));
    }

    return sessions;
  }

  @override
  Stream<CookSession> watchSession(String sessionId) {
    // Create or reuse stream controller for this session
    if (!_sessionStreamControllers.containsKey(sessionId)) {
      _sessionStreamControllers[sessionId] =
          StreamController<CookSession>.broadcast();
    }

    return _sessionStreamControllers[sessionId]!.stream;
  }

  @override
  Future<void> updateNotes(String sessionId, String notes) async {
    final box = LocalStorageService.getCookSessionsBox();
    final sessionModel = box.get(sessionId);

    if (sessionModel == null) {
      throw Exception('Session not found: $sessionId');
    }

    // Update notes
    sessionModel.notes = notes;

    // Save back to Hive
    await sessionModel.save();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    // Delete temperature readings from SQLite
    await TemperatureDatabaseHelper.instance
        .deleteReadingsBySession(sessionId);

    // Delete session from Hive
    final box = LocalStorageService.getCookSessionsBox();
    await box.delete(sessionId);

    // Close stream controller if exists
    if (_sessionStreamControllers.containsKey(sessionId)) {
      await _sessionStreamControllers[sessionId]!.close();
      _sessionStreamControllers.remove(sessionId);
    }
  }

  @override
  Future<List<CookSession>> getSessionsForDevice(String deviceId) async {
    final box = LocalStorageService.getCookSessionsBox();
    final sessionModels = box.values
        .where((model) => model.deviceId == deviceId)
        .toList();

    // Sort by start time (most recent first)
    sessionModels.sort((a, b) => b.startTime.compareTo(a.startTime));

    // Convert to domain entities
    final sessions = <CookSession>[];
    for (final model in sessionModels) {
      final readings = await TemperatureDatabaseHelper.instance
          .getReadingsBySession(model.id);

      sessions.add(CookSession(
        id: model.id,
        startTime: model.startTime,
        endTime: model.endTime,
        deviceId: model.deviceId,
        readings: readings,
        notes: model.notes,
        program: null, // TODO: Load program if programId is set
      ));
    }

    return sessions;
  }

  @override
  Future<CookSession?> getActiveSession(String deviceId) async {
    final box = LocalStorageService.getCookSessionsBox();
    final sessionModels = box.values
        .where((model) => model.deviceId == deviceId && model.endTime == null)
        .toList();

    if (sessionModels.isEmpty) {
      return null;
    }

    // Get the most recent active session
    sessionModels.sort((a, b) => b.startTime.compareTo(a.startTime));
    final model = sessionModels.first;

    // Get temperature readings from SQLite
    final readings = await TemperatureDatabaseHelper.instance
        .getReadingsBySession(model.id);

    return CookSession(
      id: model.id,
      startTime: model.startTime,
      endTime: model.endTime,
      deviceId: model.deviceId,
      readings: readings,
      notes: model.notes,
      program: null, // TODO: Load program if programId is set
    );
  }

  /// Add a temperature reading to a session
  /// 
  /// This is a helper method for adding readings during an active cook.
  /// It stores the reading in SQLite and notifies stream watchers.
  Future<void> addReading(String sessionId, TemperatureReading reading) async {
    // Store reading in SQLite
    await TemperatureDatabaseHelper.instance.insertReading(reading, sessionId);

    // Notify stream watchers
    if (_sessionStreamControllers.containsKey(sessionId)) {
      final session = await getSession(sessionId);
      _sessionStreamControllers[sessionId]!.add(session);
    }
  }

  /// Dispose all stream controllers
  void dispose() {
    for (final controller in _sessionStreamControllers.values) {
      controller.close();
    }
    _sessionStreamControllers.clear();
  }
}
