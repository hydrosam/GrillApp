import '../entities/cook_program.dart';

/// Repository for cook program management
/// 
/// Handles creation, persistence, and retrieval of cook programs
/// with multi-stage temperature control sequences.
abstract class CookProgramRepository {
  /// Save a cook program
  /// 
  /// Persists a new or updated cook program to local storage.
  /// If a program with the same ID exists, it will be updated.
  /// 
  /// Requirements: 4.1
  Future<void> saveProgram(CookProgram program);

  /// Get a specific cook program
  /// 
  /// Retrieves a program by ID including all stages and configuration.
  /// 
  /// Requirements: 4.1
  Future<CookProgram> getProgram(String programId);

  /// Get all cook programs
  /// 
  /// Retrieves all saved cook programs, ordered alphabetically by name.
  /// Used for displaying the program list.
  /// 
  /// Requirements: 4.1
  Future<List<CookProgram>> getAllPrograms();

  /// Delete a cook program
  /// 
  /// Removes a program from storage. This does not affect
  /// historical cook sessions that used this program.
  /// 
  /// Requirements: 4.1
  Future<void> deleteProgram(String programId);

  /// Update program status
  /// 
  /// Updates the execution status of a program (idle, running,
  /// paused, completed). Used during program execution.
  /// 
  /// Requirements: 4.3
  Future<void> updateProgramStatus(
    String programId,
    CookProgramStatus status,
  );

  /// Watch real-time updates for a program
  /// 
  /// Returns a stream that emits program updates, particularly
  /// useful for monitoring status changes during execution.
  /// 
  /// Requirements: 4.3
  Stream<CookProgram> watchProgram(String programId);

  /// Duplicate a cook program
  /// 
  /// Creates a copy of an existing program with a new ID and name.
  /// Useful for creating variations of successful programs.
  /// 
  /// Requirements: 4.1
  Future<CookProgram> duplicateProgram(
    String programId,
    String newName,
  );
}
