import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/domain/entities/entities.dart';
import 'package:faker/faker.dart';

void main() {
  group('TemperatureReading Property Tests', () {
    final faker = Faker();

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

    test('Property 1: Temperature Reading Persistence Round-Trip', () {
      // **Validates: Requirements 2.3, 10.1, 10.3**
      // Feature: grill-controller-app, Property 1: Temperature reading round-trip
      //
      // For any temperature reading with a probe ID, temperature value, and timestamp,
      // storing the reading and then retrieving it from local storage should produce
      // an equivalent reading with the same probe ID, temperature value, and timestamp.
      
      const iterations = 100;
      int passedIterations = 0;
      
      for (int i = 0; i < iterations; i++) {
        // Generate random temperature reading
        final original = generateRandomTemperatureReading();
        
        // Serialize to JSON (simulates storage)
        final json = original.toJson();
        
        // Deserialize from JSON (simulates retrieval)
        final retrieved = TemperatureReading.fromJson(json);
        
        // Verify equivalence - all fields must match
        expect(
          retrieved.probeId,
          equals(original.probeId),
          reason: 'Probe ID should be preserved through serialization (iteration $i)',
        );
        
        expect(
          retrieved.temperature,
          closeTo(original.temperature, 0.01),
          reason: 'Temperature should be preserved through serialization (iteration $i)',
        );
        
        expect(
          retrieved.timestamp,
          equals(original.timestamp),
          reason: 'Timestamp should be preserved through serialization (iteration $i)',
        );
        
        expect(
          retrieved.type,
          equals(original.type),
          reason: 'Probe type should be preserved through serialization (iteration $i)',
        );
        
        // Verify using Equatable equality
        expect(
          retrieved,
          equals(original),
          reason: 'Retrieved reading should equal original reading (iteration $i)',
        );
        
        passedIterations++;
      }
      
      // Verify all iterations passed
      expect(passedIterations, equals(iterations),
          reason: 'All $iterations iterations should pass');
    });

    test('Property 1: Temperature Reading Round-Trip with Edge Cases', () {
      // Test edge cases that might not be covered by random generation
      final edgeCases = [
        // Minimum temperature
        TemperatureReading(
          probeId: 'edge-min-temp',
          temperature: 32.0,
          timestamp: DateTime(2024, 1, 1),
          type: ProbeType.grill,
        ),
        // Maximum temperature
        TemperatureReading(
          probeId: 'edge-max-temp',
          temperature: 1000.0,
          timestamp: DateTime(2024, 12, 31, 23, 59, 59),
          type: ProbeType.food1,
        ),
        // Zero temperature (below freezing)
        TemperatureReading(
          probeId: 'edge-zero',
          temperature: 0.0,
          timestamp: DateTime.now(),
          type: ProbeType.food2,
        ),
        // Fractional temperature
        TemperatureReading(
          probeId: 'edge-fractional',
          temperature: 250.123456789,
          timestamp: DateTime.now(),
          type: ProbeType.food3,
        ),
        // Very old timestamp
        TemperatureReading(
          probeId: 'edge-old-timestamp',
          temperature: 225.0,
          timestamp: DateTime(2020, 1, 1),
          type: ProbeType.grill,
        ),
      ];

      for (int i = 0; i < edgeCases.length; i++) {
        final original = edgeCases[i];
        
        // Serialize and deserialize
        final json = original.toJson();
        final retrieved = TemperatureReading.fromJson(json);
        
        // Verify equivalence
        expect(
          retrieved,
          equals(original),
          reason: 'Edge case $i should round-trip correctly',
        );
      }
    });

    test('Property 1: Temperature Reading Round-Trip preserves all ProbeTypes', () {
      // Ensure all probe types can be serialized and deserialized correctly
      for (final probeType in ProbeType.values) {
        final original = TemperatureReading(
          probeId: 'probe-${probeType.name}',
          temperature: 250.0,
          timestamp: DateTime.now(),
          type: probeType,
        );
        
        final json = original.toJson();
        final retrieved = TemperatureReading.fromJson(json);
        
        expect(
          retrieved.type,
          equals(probeType),
          reason: 'ProbeType.${probeType.name} should round-trip correctly',
        );
        
        expect(retrieved, equals(original));
      }
    });
  });
}
