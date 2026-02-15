import '../datasources/local_storage_service.dart';
import '../models/user_preferences.dart';

/// Repository for managing user preferences
class PreferencesRepositoryImpl {
  static const String _preferencesKey = 'user_preferences';

  /// Save user preferences
  Future<void> savePreferences(UserPreferences preferences) async {
    final box = LocalStorageService.getPreferencesBox();
    await box.put(_preferencesKey, preferences.toJson());
  }

  /// Load user preferences
  Future<UserPreferences> loadPreferences() async {
    final box = LocalStorageService.getPreferencesBox();
    final data = box.get(_preferencesKey);
    
    if (data == null) {
      return UserPreferences.defaultPreferences();
    }
    
    return UserPreferences.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Clear preferences (reset to defaults)
  Future<void> clearPreferences() async {
    final box = LocalStorageService.getPreferencesBox();
    await box.delete(_preferencesKey);
  }
}
