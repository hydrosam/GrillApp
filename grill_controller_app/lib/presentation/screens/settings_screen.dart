import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_dependencies.dart';
import '../../data/datasources/local_storage_service.dart';
import '../../data/models/user_preferences.dart';
import '../bloc/settings_cubit.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final preferences = state.preferences;
        final adjustments = Map<String, dynamic>.from(
          preferences.fanSpeedCurveAdjustments ?? const {},
        );
        final multiplier = (adjustments['multiplier'] as num?)?.toDouble() ?? 1.0;
        final lowBoost = (adjustments['lowDeltaBoost'] as num?)?.toDouble() ?? 0.0;
        final highBoost =
            (adjustments['highDeltaBoost'] as num?)?.toDouble() ?? 0.0;

        return ListView(
          children: [
            SectionCard(
              title: 'Preferences',
              subtitle:
                  'Tune the control profile for your cooker and pick the unit language that feels natural.',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: preferences.grillType,
                    decoration: const InputDecoration(labelText: 'Grill type'),
                    items: const [
                      DropdownMenuItem(value: 'standard', child: Text('Standard')),
                      DropdownMenuItem(value: 'ceramic', child: Text('Ceramic')),
                      DropdownMenuItem(value: 'kettle', child: Text('Kettle')),
                      DropdownMenuItem(value: 'smoker', child: Text('Smoker')),
                      DropdownMenuItem(value: 'offset', child: Text('Offset')),
                    ],
                    onChanged: (value) => _update(
                      context,
                      preferences.copyWith(grillType: value ?? preferences.grillType),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'F', label: Text('Fahrenheit')),
                      ButtonSegment(value: 'C', label: Text('Celsius')),
                    ],
                    selected: {preferences.temperatureUnit},
                    onSelectionChanged: (selection) => _update(
                      context,
                      preferences.copyWith(temperatureUnit: selection.first),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SliderSetting(
                    label: 'Base airflow multiplier',
                    value: multiplier,
                    min: 0.6,
                    max: 1.4,
                    onChanged: (value) => _update(
                      context,
                      preferences.copyWith(
                        fanSpeedCurveAdjustments: {
                          ...adjustments,
                          'multiplier': value,
                        },
                      ),
                    ),
                  ),
                  _SliderSetting(
                    label: 'Low-delta boost',
                    value: lowBoost,
                    min: 0,
                    max: 20,
                    onChanged: (value) => _update(
                      context,
                      preferences.copyWith(
                        fanSpeedCurveAdjustments: {
                          ...adjustments,
                          'lowDeltaBoost': value,
                        },
                      ),
                    ),
                  ),
                  _SliderSetting(
                    label: 'High-delta boost',
                    value: highBoost,
                    min: 0,
                    max: 20,
                    onChanged: (value) => _update(
                      context,
                      preferences.copyWith(
                        fanSpeedCurveAdjustments: {
                          ...adjustments,
                          'highDeltaBoost': value,
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Data Management',
              subtitle:
                  'Export your local data, reset cache, or wipe the workspace back to a clean local state.',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _exportData(context),
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmClear(context),
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Clear Cache'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.read<SettingsCubit>().reset(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Preferences'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionCard(
              title: 'About',
              subtitle:
                  'Cross-platform grill controller for Android, iOS, and Windows.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version 1.0.0+1'),
                  SizedBox(height: 8),
                  Text('Supports Bluetooth pairing, WiFi monitoring, cook programs, history, and sharing.'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _update(BuildContext context, UserPreferences preferences) {
    context.read<SettingsCubit>().updatePreferences(preferences);
  }

  Future<void> _exportData(BuildContext context) async {
    final dependencies = context.read<AppDependencies>();
    final sessions = await dependencies.cookSessionRepository.getAllSessions();
    final programs = await dependencies.cookProgramRepository.getAllPrograms();
    final preferences = await dependencies.preferencesRepository.loadPreferences();

    final payload = {
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'programs': programs.map((program) => program.toJson()).toList(),
      'preferences': preferences.toJson(),
    };

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/grill-controller-export.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    await SharePlus.instance.share(
      ShareParams(
        text: 'Grill Controller local data export',
        files: [XFile(file.path)],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear local cache?'),
            content: const Text(
              'This removes saved devices, cook sessions, programs, and preferences from local storage.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldClear) {
      return;
    }

    await LocalStorageService.clearAllData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local cache cleared. Restart the app to reseed sample data.')),
      );
    }
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
