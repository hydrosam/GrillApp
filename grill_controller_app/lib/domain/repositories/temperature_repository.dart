import '../entities/temperature_reading.dart';

/// Repository for temperature monitoring and history
/// 
/// Handles real-time temperature streaming from devices and
/// persistence of temperature readings for historical analysis.
abstract class TemperatureRepository {
  /// Watch real-time temperature updates from a device
  /// 
  /// Returns a stream that emits temperature readings from all
  /// active probes on the device. Updates should occur at least
  /// once every 5 seconds.
  /// 
  /// Requirements: 2.2, 2.6
  Stream<TemperatureReading> watchTemperatures(String deviceId);

  /// Save a temperature reading to local storage
  /// 
  /// Persists a temperature reading for historical analysis.
  /// Readings should be saved at least once per minute during
  /// active cook sessions.
  /// 
  /// Requirements: 2.3, 10.1, 10.4
  Future<void> saveReading(TemperatureReading reading);

  /// Get temperature history for a time range
  /// 
  /// Retrieves all temperature readings for a device within
  /// the specified time range. Used for displaying historical
  /// graphs and analyzing cook sessions.
  /// 
  /// Requirements: 2.3, 2.4
  Future<List<TemperatureReading>> getHistory(
    String deviceId,
    DateTime start,
    DateTime end,
  );

  /// Get temperature history for a specific session
  /// 
  /// Retrieves all temperature readings associated with a
  /// particular cook session.
  /// 
  /// Requirements: 2.3, 6.4
  Future<List<TemperatureReading>> getSessionHistory(String sessionId);

  /// Delete temperature readings older than a specified date
  /// 
  /// Removes old temperature data to manage storage space.
  /// Typically used to keep only the last 30 days of data.
  /// 
  /// Requirements: 10.1
  Future<void> deleteOldReadings(DateTime before);

  /// Get the latest reading for a specific probe
  /// 
  /// Returns the most recent temperature reading for a probe,
  /// useful for current temperature display.
  /// 
  /// Requirements: 2.1, 2.2
  Future<TemperatureReading?> getLatestReading(
    String deviceId,
    ProbeType probeType,
  );
}
