import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/fan_controller.dart';
import '../bloc/fan_control_bloc.dart';
import '../bloc/grill_open_detection_bloc.dart';
import '../widgets/section_card.dart';

class FanControlScreen extends StatelessWidget {
  const FanControlScreen({
    super.key,
    required this.deviceId,
  });

  final String? deviceId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FanControlBloc, FanControlState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        final grillOpenState = context.watch<GrillOpenDetectionBloc>().state;
        final isGrillOpen = grillOpenState is GrillOpen;

        return ListView(
          children: [
            SectionCard(
              title: 'Air Management',
              subtitle:
                  'Automatic mode chases the target for you; manual mode gives you direct fan control.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricTile(
                        label: 'Target',
                        value:
                            '${snapshot.targetTemperature.toStringAsFixed(0)}°F',
                      ),
                      _MetricTile(
                        label: 'Current',
                        value:
                            '${snapshot.currentTemperature.toStringAsFixed(0)}°F',
                      ),
                      _MetricTile(
                        label: 'Delta',
                        value:
                            '${snapshot.temperatureDelta.toStringAsFixed(0)}°F',
                      ),
                      _MetricTile(
                        label: 'Fan',
                        value: '${snapshot.fanSpeed}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<FanControlMode>(
                    segments: const [
                      ButtonSegment(
                        value: FanControlMode.automatic,
                        label: Text('Automatic'),
                        icon: Icon(Icons.auto_awesome),
                      ),
                      ButtonSegment(
                        value: FanControlMode.manual,
                        label: Text('Manual'),
                        icon: Icon(Icons.tune),
                      ),
                    ],
                    selected: {
                      snapshot.mode == FanControlMode.manual
                          ? FanControlMode.manual
                          : FanControlMode.automatic,
                    },
                    onSelectionChanged: (selection) {
                      final mode = selection.first;
                      if (mode == FanControlMode.automatic) {
                        context
                            .read<FanControlBloc>()
                            .add(const EnableAutomatic());
                      } else {
                        context
                            .read<FanControlBloc>()
                            .add(const DisableAutomatic());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Target temperature',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: snapshot.targetTemperature.clamp(150, 450),
                    min: 150,
                    max: 450,
                    divisions: 60,
                    label:
                        '${snapshot.targetTemperature.toStringAsFixed(0)}°F',
                    onChanged: (value) => context
                        .read<FanControlBloc>()
                        .add(SetTargetTemperature(value)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Manual speed',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: snapshot.fanSpeed.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${snapshot.fanSpeed}%',
                    onChanged: snapshot.mode == FanControlMode.manual || isGrillOpen
                        ? (value) => context
                            .read<FanControlBloc>()
                            .add(SetManualSpeed(value.round()))
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Grill-Open Protection',
              subtitle:
                  'The fan cuts immediately when a lid-open event is detected, then resumes when the cooker stabilizes.',
              child: Row(
                children: [
                  Chip(
                    avatar: Icon(
                      isGrillOpen ? Icons.warning_amber : Icons.check_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      isGrillOpen ? 'Grill open' : 'Stable airflow',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: isGrillOpen
                        ? const Color(0xFFB34700)
                        : const Color(0xFF2F6A49),
                  ),
                  const SizedBox(width: 12),
                  if (isGrillOpen)
                    OutlinedButton.icon(
                      onPressed: () => context
                          .read<GrillOpenDetectionBloc>()
                          .add(const ManualResume()),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Resume manually'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2D2BB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF7F6144))),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
