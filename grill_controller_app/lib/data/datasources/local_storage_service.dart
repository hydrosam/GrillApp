import 'package:hive_flutter/hive_flutter.dart';
import '../models/device_model.dart';
import '../models/cook_session_model.dart';
import 'temperature_database_helper.dart';

/// Service for managing local storage with Hive and SQLite
class LocalStorageService {
  static const String devicesBoxName = 'devices';
  static const String cookSessionsBoxName = 'cook_sessions';
  static const String preferencesBoxName = 'preferences';

  /// Initialize Hive and SQLite
  static Future<void> initialize() async {
    // Initialize Hive with Flutter
    await Hive.initFlutter();

    // Register type adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DeviceModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CookSessionModelAdapter());
    }

    // Open boxes
    await openBoxes();

    // Initialize SQLite database for temperature readings
    await TemperatureDatabaseHelper.instance.database;
  }

  /// Open all Hive boxes
  static Future<void> openBoxes() async {
    await Hive.openBox<DeviceModel>(devicesBoxName);
    await Hive.openBox<CookSessionModel>(cookSessionsBoxName);
    await Hive.openBox(preferencesBoxName);
  }

  /// Get the devices box
  static Box<DeviceModel> getDevicesBox() {
    return Hive.box<DeviceModel>(devicesBoxName);
  }

  /// Get the cook sessions box
  static Box<CookSessionModel> getCookSessionsBox() {
    return Hive.box<CookSessionModel>(cookSessionsBoxName);
  }

  /// Get the preferences box
  static Box getPreferencesBox() {
    return Hive.box(preferencesBoxName);
  }

  /// Close all boxes
  static Future<void> closeBoxes() async {
    await Hive.close();
  }

  /// Clear all data (for testing or user-initiated reset)
  static Future<void> clearAllData() async {
    await getDevicesBox().clear();
    await getCookSessionsBox().clear();
    await getPreferencesBox().clear();
  }
}
