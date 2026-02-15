# Temperature Database Helper

## Overview

The `TemperatureDatabaseHelper` provides SQLite-based storage for temperature readings with efficient time-series query support. This is optimized for storing and retrieving large volumes of temperature data from grill and food probes.

## Database Schema

### Table: temperature_readings

| Column | Type | Description |
|--------|------|-------------|
| id | TEXT | Primary key (UUID) |
| session_id | TEXT | Foreign key to cook session |
| probe_id | TEXT | Identifier for the probe |
| temperature | REAL | Temperature in Fahrenheit |
| timestamp | INTEGER | Unix timestamp in milliseconds |
| probe_type | TEXT | Type of probe (grill, food1, food2, food3) |

### Indexes

The following indexes are created for efficient time-series queries:

1. **idx_timestamp** - Index on `timestamp` column
   - Optimizes time-range queries
   
2. **idx_session_id** - Index on `session_id` column
   - Optimizes session-specific queries
   
3. **idx_session_timestamp** - Composite index on `(session_id, timestamp)`
   - Optimizes session history queries with time ordering
   
4. **idx_probe_id** - Index on `probe_id` column
   - Optimizes probe-specific queries

## Usage

### Initialization

The database is automatically initialized when `LocalStorageService.initialize()` is called during app startup.

```dart
await LocalStorageService.initialize();
```

### Insert Temperature Reading

```dart
final dbHelper = TemperatureDatabaseHelper.instance;
final reading = TemperatureReading(
  probeId: 'probe1',
  temperature: 225.5,
  timestamp: DateTime.now(),
  type: ProbeType.grill,
);

final id = await dbHelper.insertReading(reading, 'session123');
```

### Batch Insert

For better performance when inserting multiple readings:

```dart
final readings = [reading1, reading2, reading3];
final ids = await dbHelper.insertReadings(readings, 'session123');
```

### Query by Session

```dart
final readings = await dbHelper.getReadingsBySession('session123');
```

### Query by Time Range

```dart
final startTime = DateTime.now().subtract(Duration(hours: 1));
final endTime = DateTime.now();
final readings = await dbHelper.getReadingsByTimeRange(startTime, endTime);
```

### Query by Session and Time Range

```dart
final readings = await dbHelper.getReadingsBySessionAndTimeRange(
  'session123',
  startTime,
  endTime,
);
```

### Get Latest Reading for Probe

```dart
final latest = await dbHelper.getLatestReadingForProbe('probe1');
```

### Delete Operations

```dart
// Delete by session
await dbHelper.deleteReadingsBySession('session123');

// Delete old data (e.g., older than 30 days)
final cutoffDate = DateTime.now().subtract(Duration(days: 30));
await dbHelper.deleteReadingsOlderThan(cutoffDate);

// Delete all readings
await dbHelper.deleteAllReadings();
```

## Performance Considerations

1. **Batch Inserts**: Use `insertReadings()` instead of multiple `insertReading()` calls for better performance.

2. **Index Usage**: The composite index on `(session_id, timestamp)` is particularly efficient for the common use case of retrieving session history in chronological order.

3. **Data Retention**: Consider implementing a data retention policy to delete old readings and keep the database size manageable. The design document suggests keeping only the last 24 hours in memory and archiving older data.

4. **Query Optimization**: All time-based queries use the indexed `timestamp` column for efficient filtering.

## Integration with Repository

The `TemperatureDatabaseHelper` should be used by the `TemperatureRepository` implementation to provide persistent storage for temperature readings:

```dart
class TemperatureRepositoryImpl implements TemperatureRepository {
  final TemperatureDatabaseHelper _dbHelper;
  
  TemperatureRepositoryImpl(this._dbHelper);
  
  @override
  Future<void> saveReading(TemperatureReading reading, String sessionId) async {
    await _dbHelper.insertReading(reading, sessionId);
  }
  
  @override
  Future<List<TemperatureReading>> getHistory(
    String sessionId,
    DateTime start,
    DateTime end,
  ) async {
    return await _dbHelper.getReadingsBySessionAndTimeRange(
      sessionId,
      start,
      end,
    );
  }
}
```

## Requirements Satisfied

This implementation satisfies the following requirements:

- **Requirement 2.3**: Store temperature readings with timestamps
- **Requirement 10.1**: Store cook history in local device storage
- **Requirement 10.4**: Persist temperature readings at least once per minute during active cooks

The indexed schema ensures efficient queries for time-series data, which is critical for displaying temperature graphs and historical data.
