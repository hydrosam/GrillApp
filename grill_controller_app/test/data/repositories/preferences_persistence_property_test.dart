import 'package:flutter_test/flutter_test.dart';
import 'package:grill_controller_app/data/models/user_preferences.dart';
import 'package:grill_controller_app/data/repositories/preferences_repository_impl.dart';
import 'package:grill_controller_app/data/datasources/local_storage_service.dart';
import 'package:faker/faker.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  group('UserPreferences Property Tests', () {
    final faker = Faker();
    late PreferencesRepositoryImpl repository;

    setUpAll(() async {
      // Initialize Hive for testing with a temporary directory
      final tempDir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(tempDir.path);
      await Hive.openBox(LocalStorageService.preferencesBoxName);
    });

    setUp(() async {
      repository = PreferencesRepositoryImpl();
      // Clear preferences before each test
      await LocalStorageService.getPreferencesBox().clear();
    });

    tearDownAll(() async {
      await Hive.close();
    });

    /// Generate random user preferences for property testing
    UserPreferences generateRandomUserPreferences() {
      // Generate random grill type
      final grillTypes = ['standard', 'kamado', 'offset', 'pellet', 'electric'];
      final grillType = grillTypes[faker.randomGenerator.integer(grillTypes.length)];
      
      // Generate random temperature unit
      final temperatureUnit = faker.randomGenerator.boolean() ? 'F' : 'C';
      
      // Generate random fan speed curve adjustments (optional)
      Map<String, dynamic>? fanSpeedCurveAdjustments;
      if (faker.randomGenerator.boolean()) {
        fanSpeedCurveAdjustments = {
          'lowTemp': faker.randomGenerator.decimal(min: 0.5, scale: 1.5),
          'midTemp': faker.randomGenerator.decimal(min: 0.8, scale: 1.2),
          'highTemp': faker.randomGenerator.decimal(min: 1.0, scale: 2.0),
        };
      }
      
      return UserPreferences(
        grillType: grillType,
        temperatureUnit: temperatureUnit,
        fanSpeedCurveAdjustments: fanSpeedCurveAdjustments,
      );
    }

    test('Property 3: User Preferences Persistence Round-Trip', () async {
      // **Validates: Requirements 10.2, 10.3**
      // Feature: grill-controller-app, Property 3: User preferences round-trip
      //
      // For any set of user preferences and grill configurations, storing them
      // to local storage and then loading them on app start should produce
      // equivalent preference values.
      
      const iterations = 100;
      int passedIterations = 0;
      
      for (int i = 0; i < iterations; i++) {
        // Generate random user preferences
        final original = generateRandomUserPreferences();
        
        // Save preferences to storage
        await repository.savePreferences(original);
        
        // Load preferences from storage
        final retrieved = await repository.loadPreferences();
        
        // Verify equivalence - all fields must match
        expect(
          retrieved.grillType,
          equals(original.grillType),
          reason: 'Grill type should be preserved through storage (iteration $i)',
        );
        
        expect(
          retrieved.temperatureUnit,
          equals(original.temperatureUnit),
          reason: 'Temperature unit should be preserved through storage (iteration $i)',
        );
        
        // Verify fan speed curve adjustments
        if (original.fanSpeedCurveAdjustments == null) {
          expect(
            retrieved.fanSpeedCurveAdjustments,
            isNull,
            reason: 'Null fan speed curve adjustments should remain null (iteration $i)',
          );
        } else {
          expect(
            retrieved.fanSpeedCurveAdjustments,
            isNotNull,
            reason: 'Fan speed curve adjustments should not be null (iteration $i)',
          );
          
          // Verify each adjustment value
          for (final key in original.fanSpeedCurveAdjustments!.keys) {
            expect(
              retrieved.fanSpeedCurveAdjustments![key],
              closeTo(original.fanSpeedCurveAdjustments![key] as double, 0.001),
              reason: 'Fan speed curve adjustment "$key" should be preserved (iteration $i)',
            );
          }
        }
        
        passedIterations++;
        
        // Clear for next iteration
        await repository.clearPreferences();
      }
      
      // Verify all iterations passed
      expect(passedIterations, equals(iterations),
          reason: 'All $iterations iterations should pass');
    });

    test('Property 3: User Preferences Round-Trip with Edge Cases', () async {
      // Test edge cases that might not be covered by random generation
      final edgeCases = [
        // Minimal preferences (no adjustments)
        const UserPreferences(
          grillType: 'standard',
          temperatureUnit: 'F',
        ),
        // Celsius unit
        const UserPreferences(
          grillType: 'kamado',
          temperatureUnit: 'C',
        ),
        // With fan speed curve adjustments
        const UserPreferences(
          grillType: 'offset',
          temperatureUnit: 'F',
          fanSpeedCurveAdjustments: {
            'lowTemp': 0.5,
            'midTemp': 1.0,
            'highTemp': 1.5,
          },
        ),
        // Empty fan speed curve adjustments
        const UserPreferences(
          grillType: 'pellet',
          temperatureUnit: 'C',
          fanSpeedCurveAdjustments: {},
        ),
        // Complex fan speed curve adjustments
        const UserPreferences(
          grillType: 'electric',
          temperatureUnit: 'F',
          fanSpeedCurveAdjustments: {
            'lowTemp': 0.123456789,
            'midTemp': 1.987654321,
            'highTemp': 2.5,
            'extraLow': 0.1,
            'extraHigh': 3.0,
          },
        ),
      ];

      for (int i = 0; i < edgeCases.length; i++) {
        final original = edgeCases[i];
        
        // Save and load
        await repository.savePreferences(original);
        final retrieved = await repository.loadPreferences();
        
        // Verify equivalence
        expect(
          retrieved.grillType,
          equals(original.grillType),
          reason: 'Edge case $i: grill type should match',
        );
        
        expect(
          retrieved.temperatureUnit,
          equals(original.temperatureUnit),
          reason: 'Edge case $i: temperature unit should match',
        );
        
        // Verify fan speed curve adjustments
        if (original.fanSpeedCurveAdjustments == null) {
          expect(
            retrieved.fanSpeedCurveAdjustments,
            isNull,
            reason: 'Edge case $i: null adjustments should remain null',
          );
        } else {
          expect(
            retrieved.fanSpeedCurveAdjustments?.keys,
            equals(original.fanSpeedCurveAdjustments!.keys),
            reason: 'Edge case $i: adjustment keys should match',
          );
          
          for (final key in original.fanSpeedCurveAdjustments!.keys) {
            expect(
              retrieved.fanSpeedCurveAdjustments![key],
              closeTo(original.fanSpeedCurveAdjustments![key] as double, 0.001),
              reason: 'Edge case $i: adjustment "$key" should match',
            );
          }
        }
        
        // Clear for next iteration
        await repository.clearPreferences();
      }
    });

    test('Property 3: Default Preferences Returned When No Data Exists', () async {
      // When no preferences are stored, loading should return default preferences
      
      // Ensure no preferences exist
      await repository.clearPreferences();
      
      // Load preferences
      final retrieved = await repository.loadPreferences();
      final defaults = UserPreferences.defaultPreferences();
      
      // Verify default values are returned
      expect(
        retrieved.grillType,
        equals(defaults.grillType),
        reason: 'Should return default grill type when no data exists',
      );
      
      expect(
        retrieved.temperatureUnit,
        equals(defaults.temperatureUnit),
        reason: 'Should return default temperature unit when no data exists',
      );
      
      expect(
        retrieved.fanSpeedCurveAdjustments,
        equals(defaults.fanSpeedCurveAdjustments),
        reason: 'Should return default adjustments when no data exists',
      );
    });

    test('Property 3: Multiple Save/Load Cycles Preserve Data', () async {
      // Verify that multiple save/load cycles don't corrupt data
      
      final original = generateRandomUserPreferences();
      
      // Perform multiple save/load cycles
      for (int cycle = 0; cycle < 10; cycle++) {
        await repository.savePreferences(original);
        final retrieved = await repository.loadPreferences();
        
        expect(
          retrieved.grillType,
          equals(original.grillType),
          reason: 'Grill type should remain consistent after cycle $cycle',
        );
        
        expect(
          retrieved.temperatureUnit,
          equals(original.temperatureUnit),
          reason: 'Temperature unit should remain consistent after cycle $cycle',
        );
        
        // Save the retrieved preferences again (simulating app restart)
        await repository.savePreferences(retrieved);
      }
      
      // Final verification
      final finalRetrieved = await repository.loadPreferences();
      expect(finalRetrieved.grillType, equals(original.grillType));
      expect(finalRetrieved.temperatureUnit, equals(original.temperatureUnit));
    });

    test('Property 3: Clear Preferences Resets to Defaults', () async {
      // Verify that clearing preferences results in defaults being returned
      
      // Save some preferences
      final preferences = generateRandomUserPreferences();
      await repository.savePreferences(preferences);
      
      // Verify they were saved
      final saved = await repository.loadPreferences();
      expect(saved.grillType, equals(preferences.grillType));
      
      // Clear preferences
      await repository.clearPreferences();
      
      // Load again - should get defaults
      final afterClear = await repository.loadPreferences();
      final defaults = UserPreferences.defaultPreferences();
      
      expect(afterClear.grillType, equals(defaults.grillType));
      expect(afterClear.temperatureUnit, equals(defaults.temperatureUnit));
      expect(afterClear.fanSpeedCurveAdjustments, equals(defaults.fanSpeedCurveAdjustments));
    });

    test('Property 3: All Temperature Units Persist Correctly', () async {
      // Ensure both temperature units can be stored and retrieved
      final units = ['F', 'C'];
      
      for (final unit in units) {
        final preferences = UserPreferences(
          grillType: 'standard',
          temperatureUnit: unit,
        );
        
        await repository.savePreferences(preferences);
        final retrieved = await repository.loadPreferences();
        
        expect(
          retrieved.temperatureUnit,
          equals(unit),
          reason: 'Temperature unit "$unit" should persist correctly',
        );
        
        await repository.clearPreferences();
      }
    });

    test('Property 3: All Grill Types Persist Correctly', () async {
      // Ensure all grill types can be stored and retrieved
      final grillTypes = ['standard', 'kamado', 'offset', 'pellet', 'electric'];
      
      for (final grillType in grillTypes) {
        final preferences = UserPreferences(
          grillType: grillType,
          temperatureUnit: 'F',
        );
        
        await repository.savePreferences(preferences);
        final retrieved = await repository.loadPreferences();
        
        expect(
          retrieved.grillType,
          equals(grillType),
          reason: 'Grill type "$grillType" should persist correctly',
        );
        
        await repository.clearPreferences();
      }
    });
  });
}
