import 'package:hive_flutter/hive_flutter.dart';
import '../models/device_model.dart';
import '../models/cook_session_model.dart';
import '../models/cook_program_model.dart';
import 'temperature_database_helper.dart';

/// Service for managing local storage with Hive and SQLite
class LocalStorageService {
  static const String devicesBoxName = 'devices';
  static const String cookSessionsBoxName = 'cook_sessions';
  static const String cookProgramsBoxName = 'cook_programs';
  static const String preferencesBoxName = 'preferences';

  static Box<DeviceModel>? _devicesBoxOverride;
  static Box<CookSessionModel>? _cookSessionsBoxOverride;
  static Box<CookProgramModel>? _cookProgramsBoxOverride;
  static Box? _preferencesBoxOverride;

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
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CookProgramModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CookStageModelAdapter());
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
    await Hive.openBox<CookProgramModel>(cookProgramsBoxName);
    await Hive.openBox(preferencesBoxName);
  }

  /// Get the devices box
  static Box<DeviceModel> getDevicesBox() {
    return _devicesBoxOverride ?? Hive.box<DeviceModel>(devicesBoxName);
  }

  /// Get the cook sessions box
  static Box<CookSessionModel> getCookSessionsBox() {
    return _cookSessionsBoxOverride ??
        Hive.box<CookSessionModel>(cookSessionsBoxName);
  }

  /// Get the cook programs box
  static Box<CookProgramModel> getCookProgramsBox() {
    return _cookProgramsBoxOverride ??
        Hive.box<CookProgramModel>(cookProgramsBoxName);
  }

  /// Get the preferences box
  static Box getPreferencesBox() {
    return _preferencesBoxOverride ?? Hive.box(preferencesBoxName);
  }

  static void setDevicesBox(Box<DeviceModel> box) {
    _devicesBoxOverride = box;
  }

  static void setCookSessionsBox(Box<CookSessionModel> box) {
    _cookSessionsBoxOverride = box;
  }

  static void setCookProgramsBox(Box<CookProgramModel> box) {
    _cookProgramsBoxOverride = box;
  }

  static void setPreferencesBox(Box box) {
    _preferencesBoxOverride = box;
  }

  static void clearOverrides() {
    _devicesBoxOverride = null;
    _cookSessionsBoxOverride = null;
    _cookProgramsBoxOverride = null;
    _preferencesBoxOverride = null;
  }

  /// Close all boxes
  static Future<void> closeBoxes() async {
    clearOverrides();
    await Hive.close();
  }

  /// Clear all data (for testing or user-initiated reset)
  static Future<void> clearAllData() async {
    await getDevicesBox().clear();
    await getCookSessionsBox().clear();
    await getCookProgramsBox().clear();
    await getPreferencesBox().clear();
  }
}
