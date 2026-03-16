import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/app_dependencies.dart';
import '../../domain/entities/cook_session.dart';
import '../../domain/entities/temperature_reading.dart';
import '../bloc/temperature_monitor_bloc.dart';
import '../widgets/section_card.dart';
import '../widgets/temperature_chart.dart';

class TemperatureDashboardScreen extends StatelessWidget {
  const TemperatureDashboardScreen({
    super.key,
    required this.deviceId,
  });

  final String? deviceId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemperatureMonitorBloc, TemperatureMonitorState>(
      builder: (context, state) {
        final latest = state.latestReadings;
        final grillReading = latest[ProbeType.grill];

        return ListView(
          children: [
            SectionCard(
              title: 'Live Fire',
              subtitle:
                  'Real-time probe readings update here once your controller is on WiFi.',
              actions: [
                OutlinedButton.icon(
                  onPressed: deviceId == null
                      ? null
                      : () => context
                          .read<TemperatureMonitorBloc>()
                          .add(StartMonitoring(deviceId!)),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Refresh'),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ProbeCard(
                        label: 'Grill',
                        color: const Color(0xFFD45B37),
                        reading: grillReading,
                      ),
                      _ProbeCard(
                        label: 'Food 1',
                        color: const Color(0xFF2D6A4F),
                        reading: latest[ProbeType.food1],
                      ),
                      _ProbeCard(
                        label: 'Food 2',
                        color: const Color(0xFF2D7DD2),
                        reading: latest[ProbeType.food2],
                      ),
                      _ProbeCard(
                        label: 'Food 3',
                        color: const Color(0xFF925E78),
                        reading: latest[ProbeType.food3],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TemperatureChart(readings: state.readings),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<CookSession>>(
              future: context
                  .read<AppDependencies>()
                  .cookSessionRepository
                  .getAllSessions(),
              builder: (context, snapshot) {
                final session = snapshot.data?.isNotEmpty == true
                    ? snapshot.data!.first
                    : null;
                return SectionCard(
                  title: 'Recent Cook Snapshot',
                  subtitle:
                      'The latest saved session is always close by for quick comparison.',
                  child: session == null
                      ? const Text('No saved sessions yet.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.program?.name ?? 'Manual cook',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              session.notes ?? 'No notes were saved for this cook.',
                              style: const TextStyle(color: Color(0xFF7F6144)),
                            ),
                            const SizedBox(height: 16),
                            TemperatureChart(readings: session.readings.take(60).toList()),
                          ],
                        ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ProbeCard extends StatelessWidget {
  const _ProbeCard({
    required this.label,
    required this.color,
    required this.reading,
  });

  final String label;
  final Color color;
  final TemperatureReading? reading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2D2BB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            reading == null
                ? '--'
                : '${reading!.temperature.toStringAsFixed(0)}°F',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF392515),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            reading == null
                ? 'Waiting for signal'
                : 'Updated ${TimeOfDay.fromDateTime(reading!.timestamp).format(context)}',
            style: const TextStyle(color: Color(0xFF7F6144)),
          ),
        ],
      ),
    );
  }
}
