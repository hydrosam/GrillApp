import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/user_preferences.dart';
import '../../data/repositories/preferences_repository_impl.dart';

class SettingsState extends Equatable {
  final UserPreferences preferences;
  final bool isSaving;
  final String? message;

  const SettingsState({
    required this.preferences,
    required this.isSaving,
    this.message,
  });

  factory SettingsState.initial() {
    return SettingsState(
      preferences: UserPreferences.defaultPreferences(),
      isSaving: false,
    );
  }

  SettingsState copyWith({
    UserPreferences? preferences,
    bool? isSaving,
    String? message,
  }) {
    return SettingsState(
      preferences: preferences ?? this.preferences,
      isSaving: isSaving ?? this.isSaving,
      message: message,
    );
  }

  @override
  List<Object?> get props => [preferences.grillType, preferences.temperatureUnit, preferences.fanSpeedCurveAdjustments, isSaving, message];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({required PreferencesRepositoryImpl preferencesRepository})
      : _preferencesRepository = preferencesRepository,
        super(SettingsState.initial());

  final PreferencesRepositoryImpl _preferencesRepository;

  Future<void> load() async {
    final preferences = await _preferencesRepository.loadPreferences();
    emit(state.copyWith(preferences: preferences, message: null));
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    emit(state.copyWith(preferences: preferences, isSaving: true, message: null));
    await _preferencesRepository.savePreferences(preferences);
    emit(state.copyWith(preferences: preferences, isSaving: false));
  }

  Future<void> reset() async {
    await _preferencesRepository.clearPreferences();
    emit(state.copyWith(
      preferences: UserPreferences.defaultPreferences(),
      message: 'Preferences reset to defaults.',
    ));
  }
}
