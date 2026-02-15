import '../entities/cook_session.dart';

/// Repository for cook session management
/// 
/// Handles creation, persistence, and retrieval of cook sessions
/// including associated notes and temperature history.
abstract class CookSessionRepository {
  /// Create a new cook session
  /// 
  /// Initializes a new cook session for the specified device.
  /// The session starts immediately and will track temperature
  /// readings until ended.
  /// 
  /// Requirements: 6.1
  Future<CookSession> createSession(String deviceId);

  /// End a cook session
  /// 
  /// Marks a session as complete and optionally saves notes.
  /// The session's end time is set to the current time.
  /// 
  /// Requirements: 6.2
  Future<void> endSession(String sessionId, String? notes);

  /// Get a specific cook session
  /// 
  /// Retrieves a session by ID including all associated data
  /// (temperature readings, notes, program).
  /// 
  /// Requirements: 6.3, 6.4
  Future<CookSession> getSession(String sessionId);

  /// Get all cook sessions
  /// 
  /// Retrieves all saved cook sessions, ordered by start time
  /// (most recent first). Used for displaying cook history.
  /// 
  /// Requirements: 6.3
  Future<List<CookSession>> getAllSessions();

  /// Watch real-time updates for a session
  /// 
  /// Returns a stream that emits session updates as temperature
  /// readings are added during an active cook.
  /// 
  /// Requirements: 2.2, 6.4
  Stream<CookSession> watchSession(String sessionId);

  /// Update session notes
  /// 
  /// Modifies the notes for an existing session. Can be called
  /// during or after a cook session.
  /// 
  /// Requirements: 6.1, 6.5
  Future<void> updateNotes(String sessionId, String notes);

  /// Delete a cook session
  /// 
  /// Removes a session and all associated data from storage.
  /// 
  /// Requirements: 6.5
  Future<void> deleteSession(String sessionId);

  /// Get sessions for a specific device
  /// 
  /// Retrieves all cook sessions associated with a particular
  /// device, useful for device-specific history.
  /// 
  /// Requirements: 6.3, 6.4
  Future<List<CookSession>> getSessionsForDevice(String deviceId);

  /// Get active session for a device
  /// 
  /// Returns the currently active (not ended) session for a device,
  /// or null if no session is active.
  /// 
  /// Requirements: 6.1
  Future<CookSession?> getActiveSession(String deviceId);
}
