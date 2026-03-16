import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_dependencies.dart';
import '../../core/utils/app_notification.dart';
import '../../domain/entities/cook_program.dart';
import '../../domain/usecases/cook_program_executor.dart';
import '../bloc/cook_program_bloc.dart';
import '../widgets/section_card.dart';

class CookProgramsScreen extends StatefulWidget {
  const CookProgramsScreen({super.key});

  @override
  State<CookProgramsScreen> createState() => _CookProgramsScreenState();
}

class _CookProgramsScreenState extends State<CookProgramsScreen> {
  final List<_KitchenTimerEntry> _timers = <_KitchenTimerEntry>[];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tickTimers());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CookProgramBloc, CookProgramState>(
      builder: (context, state) {
        return ListView(
          children: [
            SectionCard(
              title: 'Cook Programs',
              subtitle:
                  'Build multi-stage plans, duplicate favorites, and run them straight from the pit.',
              actions: [
                ElevatedButton.icon(
                  onPressed: () => _showProgramEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Program'),
                ),
              ],
              child: Column(
                children: [
                  for (final program in state.programs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProgramTile(program: program),
                    ),
                  if (state.programs.isEmpty)
                    const Text('No programs saved yet. Add one to get started.'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (state.execution != null)
              SectionCard(
                title: 'Execution',
                subtitle:
                    'Live stage progress, alerts, and direct execution controls.',
                child: _ExecutionPanel(execution: state.execution!),
              ),
            if (state.execution != null) const SizedBox(height: 18),
            SectionCard(
              title: 'Kitchen Timers',
              subtitle:
                  'Quick ad-hoc timers for wraps, spritzes, or rest periods.',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _showTimerDialog(context),
                  icon: const Icon(Icons.timer),
                  label: const Text('Add Timer'),
                ),
              ],
              child: Column(
                children: [
                  if (_timers.isEmpty)
                    const Text('No active timers.')
                  else
                    ..._timers.map(
                      (timer) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(timer.label),
                        subtitle: Text(_formatDuration(timer.remaining)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _timers.remove(timer)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showProgramEditor(BuildContext context) async {
    final result = await showDialog<CookProgram>(
      context: context,
      builder: (_) => const _ProgramEditorDialog(),
    );

    if (result == null || !mounted) {
      return;
    }

    context.read<CookProgramBloc>().add(SaveProgram(result));
  }

  Future<void> _showTimerDialog(BuildContext context) async {
    final labelController = TextEditingController();
    final minutesController = TextEditingController(text: '15');

    final created = await showDialog<_KitchenTimerEntry>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutes'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final minutes = int.tryParse(minutesController.text) ?? 15;
              Navigator.of(context).pop(
                _KitchenTimerEntry(
                  label: labelController.text.trim().isEmpty
                      ? 'Kitchen timer'
                      : labelController.text.trim(),
                  endsAt: DateTime.now().add(Duration(minutes: minutes)),
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    labelController.dispose();
    minutesController.dispose();

    if (created == null) {
      return;
    }

    setState(() => _timers.add(created));
  }

  void _tickTimers() {
    if (!mounted || _timers.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final expired = _timers.where((timer) => timer.endsAt.isBefore(now)).toList();
    if (expired.isNotEmpty) {
      final notifications = context.read<AppDependencies>().notifications;
      for (final timer in expired) {
        notifications.push(
          title: 'Timer complete',
          message: timer.label,
          type: AppNotificationType.alert,
        );
      }
      setState(() {
        _timers.removeWhere((timer) => expired.contains(timer));
      });
      return;
    }

    setState(() {});
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile({required this.program});

  final CookProgram program;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6D4BD)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  program.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(program.status.name.toUpperCase()),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < program.stages.length; index++)
                Chip(
                  label: Text(
                    'Stage ${index + 1}: ${program.stages[index].targetTemperature.toStringAsFixed(0)}°F / ${program.stages[index].duration.inMinutes}m',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => context
                    .read<CookProgramBloc>()
                    .add(StartProgram(program.id)),
                child: const Text('Start'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => context.read<CookProgramBloc>().add(
                      DuplicateProgram(
                        programId: program.id,
                        newName: '${program.name} Copy',
                      ),
                    ),
                child: const Text('Duplicate'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => context
                    .read<CookProgramBloc>()
                    .add(DeleteProgram(program.id)),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecutionPanel extends StatelessWidget {
  const _ExecutionPanel({required this.execution});

  final CookProgramExecutionSnapshot execution;

  @override
  Widget build(BuildContext context) {
    final stage = execution.currentStage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          execution.program.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        if (stage != null)
          Text(
            'Stage ${execution.currentStageIndex + 1}: ${stage.targetTemperature.toStringAsFixed(0)}°F • ${execution.stageRemaining.inMinutes}m remaining',
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: [
            if (execution.status == CookProgramExecutionStatus.running)
              OutlinedButton.icon(
                onPressed: () => context
                    .read<CookProgramBloc>()
                    .add(const PauseProgram()),
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
            if (execution.status == CookProgramExecutionStatus.paused)
              OutlinedButton.icon(
                onPressed: () => context
                    .read<CookProgramBloc>()
                    .add(const ResumeProgram()),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
            OutlinedButton.icon(
              onPressed: () =>
                  context.read<CookProgramBloc>().add(const StageComplete()),
              icon: const Icon(Icons.skip_next),
              label: const Text('Next stage'),
            ),
            TextButton.icon(
              onPressed: () =>
                  context.read<CookProgramBloc>().add(const StopProgram()),
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final alert in execution.alerts.reversed.take(4))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(alert.message),
            subtitle: Text(alert.timestamp.toLocal().toString()),
          ),
      ],
    );
  }
}

class _ProgramEditorDialog extends StatefulWidget {
  const _ProgramEditorDialog();

  @override
  State<_ProgramEditorDialog> createState() => _ProgramEditorDialogState();
}

class _ProgramEditorDialogState extends State<_ProgramEditorDialog> {
  final _nameController = TextEditingController();
  final List<_EditableStage> _stages = [_EditableStage()];

  @override
  void dispose() {
    _nameController.dispose();
    for (final stage in _stages) {
      stage.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Cook Program'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Program name'),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < _stages.length; index++) ...[
                _StageEditorCard(
                  title: 'Stage ${index + 1}',
                  stage: _stages[index],
                  onRemove: _stages.length == 1
                      ? null
                      : () => setState(() {
                            _stages.removeAt(index).dispose();
                          }),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: () => setState(() => _stages.add(_EditableStage())),
                icon: const Icon(Icons.add),
                label: const Text('Add stage'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final uuid = const Uuid();
            final program = CookProgram(
              id: uuid.v4(),
              name: _nameController.text.trim().isEmpty
                  ? 'Untitled Program'
                  : _nameController.text.trim(),
              stages: _stages
                  .map(
                    (stage) => CookStage(
                      targetTemperature:
                          double.tryParse(stage.tempController.text) ?? 250,
                      duration: Duration(
                        minutes:
                            int.tryParse(stage.minutesController.text) ?? 60,
                      ),
                      alertOnComplete: stage.alertOnComplete,
                    ),
                  )
                  .toList(),
              status: CookProgramStatus.idle,
            );
            Navigator.of(context).pop(program);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _StageEditorCard extends StatefulWidget {
  const _StageEditorCard({
    required this.title,
    required this.stage,
    this.onRemove,
  });

  final String title;
  final _EditableStage stage;
  final VoidCallback? onRemove;

  @override
  State<_StageEditorCard> createState() => _StageEditorCardState();
}

class _StageEditorCardState extends State<_StageEditorCard> {

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0E5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title)),
              if (widget.onRemove != null)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.stage.tempController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target temperature'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.stage.minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutes'),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alert on completion'),
            value: widget.stage.alertOnComplete,
            onChanged: (value) => setState(() => widget.stage.setAlert(value)),
          ),
        ],
      ),
    );
  }
}

class _EditableStage {
  _EditableStage()
      : tempController = TextEditingController(text: '250'),
        minutesController = TextEditingController(text: '60');

  final TextEditingController tempController;
  final TextEditingController minutesController;
  bool alertOnComplete = true;

  void setAlert(bool value) {
    alertOnComplete = value;
  }

  void dispose() {
    tempController.dispose();
    minutesController.dispose();
  }
}

class _KitchenTimerEntry {
  _KitchenTimerEntry({
    required this.label,
    required this.endsAt,
  });

  final String label;
  final DateTime endsAt;

  Duration get remaining {
    final duration = endsAt.difference(DateTime.now());
    return duration.isNegative ? Duration.zero : duration;
  }
}
