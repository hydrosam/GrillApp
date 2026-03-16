import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/app_dependencies.dart';
import '../../core/utils/app_notification.dart';
import '../../core/utils/layout_breakpoints.dart';
import '../../domain/entities/grill_device.dart';
import '../../domain/entities/probe.dart';
import '../../domain/entities/temperature_reading.dart';
import '../../data/models/user_preferences.dart';
import '../bloc/cook_program_bloc.dart';
import '../bloc/device_connection_bloc.dart';
import '../bloc/fan_control_bloc.dart';
import '../bloc/grill_open_detection_bloc.dart';
import '../bloc/settings_cubit.dart';
import '../bloc/temperature_monitor_bloc.dart';
import 'cook_history_screen.dart';
import 'cook_programs_screen.dart';
import 'device_connection_screen.dart';
import 'fan_control_screen.dart';
import 'settings_screen.dart';
import 'temperature_dashboard_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  StreamSubscription<AppNotification>? _notificationSubscription;

  static const _titles = [
    'Connect',
    'Temperatures',
    'Fan Control',
    'Programs',
    'History',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CookProgramBloc>().add(const LoadPrograms());
    });

    final dependencies = context.read<AppDependencies>();
    _notificationSubscription = dependencies.notifications.stream.listen((item) {
      final color = switch (item.type) {
        AppNotificationType.error => const Color(0xFF8B1E3F),
        AppNotificationType.warning => const Color(0xFF9C4A22),
        AppNotificationType.success => const Color(0xFF2F6A49),
        AppNotificationType.alert => const Color(0xFFB34700),
        AppNotificationType.info => const Color(0xFF365A7B),
      };

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: color,
          content: Text('${item.title}: ${item.message}'),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final deviceId = _activeDeviceId;
    if (deviceId == null) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<TemperatureMonitorBloc>().add(const StopMonitoring());
    }

    if (state == AppLifecycleState.resumed &&
        context.read<DeviceConnectionBloc>().state is DeviceWifiConnected) {
      context.read<TemperatureMonitorBloc>().add(StartMonitoring(deviceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<DeviceConnectionBloc, DeviceConnectionState>(
          listenWhen: (previous, current) =>
              previous.selectedDevice != current.selectedDevice ||
              previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            final device = state.selectedDevice;
            final preferences = context.read<SettingsCubit>().state.preferences;

            if (state is DeviceWifiConnected && device != null) {
              context
                  .read<TemperatureMonitorBloc>()
                  .add(StartMonitoring(device.id));
            }

            if (state is DeviceDisconnected) {
              context.read<TemperatureMonitorBloc>().add(const StopMonitoring());
            }

            if (device != null) {
              final effectiveDeviceId =
                  device.status == ConnectionStatus.wifi ? device.id : 'preview';
              context.read<FanControlBloc>().add(
                    InitializeFanControl(
                      deviceId: effectiveDeviceId,
                      currentTemperature:
                          _latestGrillTemperature(context) ?? 225,
                      targetTemperature:
                          _grillProbe(device)?.targetTemperature ?? 250,
                      grillType: preferences.grillType,
                      deviceType: device.type,
                      curveAdjustments:
                          _curveAdjustments(preferences),
                    ),
                  );
            }
          },
        ),
        BlocListener<TemperatureMonitorBloc, TemperatureMonitorState>(
          listenWhen: (previous, current) =>
              previous.readings.length != current.readings.length &&
              current.readings.isNotEmpty,
          listener: (context, state) {
            final reading = state.readings.last;
            if (reading.type != ProbeType.grill) {
              return;
            }
            context.read<GrillOpenDetectionBloc>().add(TemperatureUpdate(reading));
            context
                .read<FanControlBloc>()
                .add(TemperatureObserved(reading.temperature));
            context
                .read<CookProgramBloc>()
                .add(ObserveProgramTemperature(reading.temperature));
          },
        ),
        BlocListener<GrillOpenDetectionBloc, GrillOpenDetectionState>(
          listener: (context, state) {
            final isOpen = state is GrillOpen;
            context.read<FanControlBloc>().add(GrillOpenStatusChanged(isOpen));
          },
        ),
        BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (previous, current) =>
              previous.preferences != current.preferences,
          listener: (context, state) {
            final device =
                context.read<DeviceConnectionBloc>().state.selectedDevice;
            if (device == null) {
              return;
            }
            final effectiveDeviceId =
                device.status == ConnectionStatus.wifi ? device.id : 'preview';
            context.read<FanControlBloc>().add(
                  InitializeFanControl(
                    deviceId: effectiveDeviceId,
                    currentTemperature: _latestGrillTemperature(context) ?? 225,
                    targetTemperature:
                        _grillProbe(device)?.targetTemperature ?? 250,
                    grillType: state.preferences.grillType,
                    deviceType: device.type,
                    curveAdjustments: _curveAdjustments(state.preferences),
                  ),
                );
          },
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = layoutSizeForWidth(constraints.maxWidth);
          final pages = _pages();
          final content = pages[_selectedIndex];

          if (size == LayoutSize.desktop) {
            return _DesktopShell(
              selectedIndex: _selectedIndex,
              onSelected: _onSelected,
              title: _titles[_selectedIndex],
              child: content,
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(_titles[_selectedIndex]),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: _ShellBackdrop(child: content),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.bluetooth_searching),
                  label: 'Connect',
                ),
                NavigationDestination(
                  icon: Icon(Icons.thermostat),
                  label: 'Temps',
                ),
                NavigationDestination(
                  icon: Icon(Icons.air),
                  label: 'Fan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.restaurant_menu),
                  label: 'Programs',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _pages() {
    return [
      const DeviceConnectionScreen(),
      TemperatureDashboardScreen(deviceId: _activeDeviceId),
      FanControlScreen(deviceId: _activeDeviceId),
      const CookProgramsScreen(),
      CookHistoryScreen(deviceId: _activeDeviceId),
      const SettingsScreen(),
    ];
  }

  String? get _activeDeviceId {
    return context.read<DeviceConnectionBloc>().state.selectedDevice?.id ??
        'demo-device';
  }

  double? _latestGrillTemperature(BuildContext context) {
    final state = context.read<TemperatureMonitorBloc>().state;
    final reading = state.latestReadings[ProbeType.grill];
    return reading?.temperature;
  }

  Probe? _grillProbe(GrillDevice device) {
    for (final probe in device.probes) {
      if (probe.type == ProbeType.grill) {
        return probe;
      }
    }
    return null;
  }

  Map<String, double> _curveAdjustments(UserPreferences preferences) {
    return Map<String, double>.from(
      (preferences.fanSpeedCurveAdjustments ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toDouble())),
    );
  }

  void _onSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.onSelected,
    required this.title,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            labelType: NavigationRailLabelType.all,
            backgroundColor: const Color(0xFFF7EFDF),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.bluetooth_searching),
                label: Text('Connect'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.thermostat),
                label: Text('Temps'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.air),
                label: Text('Fan'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.restaurant_menu),
                label: Text('Programs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          Expanded(
            child: _ShellBackdrop(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF4E8D4), Color(0xFFE7D0AE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x22B5651D),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x222D6A4F),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
