import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/temperature_reading.dart';

/// Database helper for managing temperature readings with SQLite
/// Provides efficient time-series storage and querying for temperature data
class TemperatureDatabaseHelper {
  static const String _databaseName = 'grill_controller.db';
  static const int _databaseVersion = 1;

  // Table and column names
  static const String tableTemperatureReadings = 'temperature_readings';
  static const String columnId = 'id';
  static const String columnSessionId = 'session_id';
  static const String columnProbeId = 'probe_id';
  static const String columnTemperature = 'temperature';
  static const String columnTimestamp = 'timestamp';
  static const String columnProbeType = 'probe_type';

  final _uuid = const Uuid();

  // Singleton instance
  static final TemperatureDatabaseHelper instance =
      TemperatureDatabaseHelper._internal();
  static Database? _database;

  TemperatureDatabaseHelper._internal();

  /// Get the database instance, initializing if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables and indexes
  Future<void> _onCreate(Database db, int version) async {
    // Create temperature_readings table
    await db.execute('''
      CREATE TABLE $tableTemperatureReadings (
        $columnId TEXT PRIMARY KEY,
        $columnSessionId TEXT NOT NULL,
        $columnProbeId TEXT NOT NULL,
        $columnTemperature REAL NOT NULL,
        $columnTimestamp INTEGER NOT NULL,
        $columnProbeType TEXT NOT NULL
      )
    ''');

    // Create indexes for efficient time-series queries
    // Index on timestamp for time-range queries
    await db.execute('''
      CREATE INDEX idx_timestamp 
      ON $tableTemperatureReadings($columnTimestamp)
    ''');

    // Index on session_id for session-specific queries
    await db.execute('''
      CREATE INDEX idx_session_id 
      ON $tableTemperatureReadings($columnSessionId)
    ''');

    // Composite index on session_id and timestamp for efficient session history queries
    await db.execute('''
      CREATE INDEX idx_session_timestamp 
      ON $tableTemperatureReadings($columnSessionId, $columnTimestamp)
    ''');

    // Index on probe_id for probe-specific queries
    await db.execute('''
      CREATE INDEX idx_probe_id 
      ON $tableTemperatureReadings($columnProbeId)
    ''');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
  }

  /// Insert a temperature reading
  Future<String> insertReading(
    TemperatureReading reading,
    String sessionId,
  ) async {
    final db = await database;
    final id = _uuid.v4();
    await db.insert(
      tableTemperatureReadings,
      _readingToMap(reading, sessionId, id),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  /// Insert multiple temperature readings in a batch
  Future<List<String>> insertReadings(
    List<TemperatureReading> readings,
    String sessionId,
  ) async {
    final db = await database;
    final batch = db.batch();
    final ids = <String>[];

    for (final reading in readings) {
      final id = _uuid.v4();
      ids.add(id);
      batch.insert(
        tableTemperatureReadings,
        _readingToMap(reading, sessionId, id),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    return ids;
  }

  /// Get a temperature reading by ID
  Future<TemperatureReading?> getReading(String id) async {
    final db = await database;
    final results = await db.query(
      tableTemperatureReadings,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _mapToReading(results.first);
  }

  /// Get all temperature readings for a session
  Future<List<TemperatureReading>> getReadingsBySession(
      String sessionId) async {
    final db = await database;
    final results = await db.query(
      tableTemperatureReadings,
      where: '$columnSessionId = ?',
      whereArgs: [sessionId],
      orderBy: '$columnTimestamp ASC',
    );

    return results.map((map) => _mapToReading(map)).toList();
  }

  /// Get temperature readings for a session within a time range
  Future<List<TemperatureReading>> getReadingsBySessionAndTimeRange(
    String sessionId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final db = await database;
    final results = await db.query(
      tableTemperatureReadings,
      where:
          '$columnSessionId = ? AND $columnTimestamp >= ? AND $columnTimestamp <= ?',
      whereArgs: [
        sessionId,
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      ],
      orderBy: '$columnTimestamp ASC',
    );

    return results.map((map) => _mapToReading(map)).toList();
  }

  /// Get temperature readings for a specific probe
  Future<List<TemperatureReading>> getReadingsByProbe(String probeId) async {
    final db = await database;
    final results = await db.query(
      tableTemperatureReadings,
      where: '$columnProbeId = ?',
      whereArgs: [probeId],
      orderBy: '$columnTimestamp ASC',
    );

    return results.map((map) => _mapToReading(map)).toList();
  }

  /// Get temperature readings within a time range
  Future<List<TemperatureReading>> getReadingsByTimeRange(
    DateTime startTime,
    DateTime endTime,
  ) async {
    final db = await database;
    final results = await db.query(
      tableTemperatureReadings,
      where: '$columnTimestamp >= ? AND $columnTimestamp <= ?',
      whereArgs: [
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      ],
      orderBy: '$columnTimestamp ASC',
    );

    return results.map((map) => _mapToReading(map)).toList();
  }

  /// Get the latest temperature reading for a probe
  Future<TemperatureReading?> getLatestReadingForProbe(String probeId) async {
    final db = await database;
    final results = await db.query(
      tableTemperatureReadings,
      where: '$columnProbeId = ?',
      whereArgs: [probeId],
      orderBy: '$columnTimestamp DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _mapToReading(results.first);
  }

  /// Delete temperature readings for a session
  Future<int> deleteReadingsBySession(String sessionId) async {
    final db = await database;
    return await db.delete(
      tableTemperatureReadings,
      where: '$columnSessionId = ?',
      whereArgs: [sessionId],
    );
  }

  /// Delete temperature readings older than a specified date
  Future<int> deleteReadingsOlderThan(DateTime date) async {
    final db = await database;
    return await db.delete(
      tableTemperatureReadings,
      where: '$columnTimestamp < ?',
      whereArgs: [date.millisecondsSinceEpoch],
    );
  }

  /// Delete all temperature readings
  Future<int> deleteAllReadings() async {
    final db = await database;
    return await db.delete(tableTemperatureReadings);
  }

  /// Get the count of temperature readings
  Future<int> getReadingsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableTemperatureReadings',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get the count of temperature readings for a session
  Future<int> getReadingsCountBySession(String sessionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableTemperatureReadings WHERE $columnSessionId = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Convert TemperatureReading to Map for database storage
  Map<String, dynamic> _readingToMap(
    TemperatureReading reading,
    String sessionId,
    String id,
  ) {
    return {
      columnId: id,
      columnSessionId: sessionId,
      columnProbeId: reading.probeId,
      columnTemperature: reading.temperature,
      columnTimestamp: reading.timestamp.millisecondsSinceEpoch,
      columnProbeType: reading.type.toString().split('.').last,
    };
  }

  /// Convert Map from database to TemperatureReading
  TemperatureReading _mapToReading(Map<String, dynamic> map) {
    return TemperatureReading(
      probeId: map[columnProbeId] as String,
      temperature: map[columnTemperature] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map[columnTimestamp] as int,
      ),
      type: _parseProbeType(map[columnProbeType] as String),
    );
  }

  /// Parse ProbeType from string
  ProbeType _parseProbeType(String typeString) {
    switch (typeString) {
      case 'grill':
        return ProbeType.grill;
      case 'food1':
        return ProbeType.food1;
      case 'food2':
        return ProbeType.food2;
      case 'food3':
        return ProbeType.food3;
      default:
        throw ArgumentError('Unknown probe type: $typeString');
    }
  }
}
