import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../core/utils/app_notification.dart';
import '../../core/utils/notification_service.dart';
import '../entities/cook_program.dart';

enum CookProgramExecutionStatus { idle, running, paused, completed, stopped }

enum CookProgramAlertType { targetReached, stageCompleted, timerExpired }

class CookProgramAlert extends Equatable {
  final CookProgramAlertType type;
  final String message;
  final int stageIndex;
  final DateTime timestamp;

  const CookProgramAlert({
    required this.type,
    required this.message,
    required this.stageIndex,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [type, message, stageIndex, timestamp];
}

class CookProgramExecutionSnapshot extends Equatable {
  final CookProgram program;
  final CookProgramExecutionStatus status;
  final int currentStageIndex;
  final DateTime? startedAt;
  final DateTime? stageStartedAt;
  final Duration elapsed;
  final Duration stageElapsed;
  final Duration stageRemaining;
  final List<CookProgramAlert> alerts;
  final bool targetReached;

  const CookProgramExecutionSnapshot({
    required this.program,
    required this.status,
    required this.currentStageIndex,
    required this.startedAt,
    required this.stageStartedAt,
    required this.elapsed,
    required this.stageElapsed,
    required this.stageRemaining,
    required this.alerts,
    required this.targetReached,
  });

  factory CookProgramExecutionSnapshot.idle(CookProgram program) {
    return CookProgramExecutionSnapshot(
      program: program,
      status: CookProgramExecutionStatus.idle,
      currentStageIndex: 0,
      startedAt: null,
      stageStartedAt: null,
      elapsed: Duration.zero,
      stageElapsed: Duration.zero,
      stageRemaining:
          program.stages.isEmpty ? Duration.zero : program.stages.first.duration,
      alerts: const [],
      targetReached: false,
    );
  }

  CookStage? get currentStage {
    if (currentStageIndex < 0 || currentStageIndex >= program.stages.length) {
      return null;
    }
    return program.stages[currentStageIndex];
  }

  @override
  List<Object?> get props => [
        program,
        status,
        currentStageIndex,
        startedAt,
        stageStartedAt,
        elapsed,
        stageElapsed,
        stageRemaining,
        alerts,
        targetReached,
      ];

  CookProgramExecutionSnapshot copyWith({
    CookProgram? program,
    CookProgramExecutionStatus? status,
    int? currentStageIndex,
    DateTime? startedAt,
    DateTime? stageStartedAt,
    Duration? elapsed,
    Duration? stageElapsed,
    Duration? stageRemaining,
    List<CookProgramAlert>? alerts,
    bool? targetReached,
  }) {
    return CookProgramExecutionSnapshot(
      program: program ?? this.program,
      status: status ?? this.status,
      currentStageIndex: currentStageIndex ?? this.currentStageIndex,
      startedAt: startedAt ?? this.startedAt,
      stageStartedAt: stageStartedAt ?? this.stageStartedAt,
      elapsed: elapsed ?? this.elapsed,
      stageElapsed: stageElapsed ?? this.stageElapsed,
      stageRemaining: stageRemaining ?? this.stageRemaining,
      alerts: alerts ?? this.alerts,
      targetReached: targetReached ?? this.targetReached,
    );
  }
}

class CookProgramExecutor {
  CookProgramExecutor({required NotificationService notifications})
      : _notifications = notifications;

  final NotificationService _notifications;
  final StreamController<CookProgramExecutionSnapshot> _controller =
      StreamController<CookProgramExecutionSnapshot>.broadcast();
  Timer? _ticker;
  CookProgramExecutionSnapshot? _snapshot;
  Duration _elapsedBeforePause = Duration.zero;
  Duration _stageElapsedBeforePause = Duration.zero;

  Stream<CookProgramExecutionSnapshot> get stream => _controller.stream;
  CookProgramExecutionSnapshot? get snapshot => _snapshot;

  CookProgramExecutionSnapshot start(CookProgram program) {
    final now = DateTime.now();
    _elapsedBeforePause = Duration.zero;
    _stageElapsedBeforePause = Duration.zero;
    _snapshot = CookProgramExecutionSnapshot(
      program: program.copyWith(status: CookProgramStatus.running),
      status: CookProgramExecutionStatus.running,
      currentStageIndex: 0,
      startedAt: now,
      stageStartedAt: now,
      elapsed: Duration.zero,
      stageElapsed: Duration.zero,
      stageRemaining:
          program.stages.isEmpty ? Duration.zero : program.stages.first.duration,
      alerts: const [],
      targetReached: false,
    );
    _startTicker();
    _emit();
    return _snapshot!;
  }

  CookProgramExecutionSnapshot pause() {
    final current = _requireSnapshot();
    _ticker?.cancel();
    _elapsedBeforePause = current.elapsed;
    _stageElapsedBeforePause = current.stageElapsed;
    _snapshot = current.copyWith(status: CookProgramExecutionStatus.paused);
    _emit();
    return _snapshot!;
  }

  CookProgramExecutionSnapshot resume() {
    final current = _requireSnapshot();
    final now = DateTime.now();
    _snapshot = current.copyWith(
      status: CookProgramExecutionStatus.running,
      startedAt: now.subtract(_elapsedBeforePause),
      stageStartedAt: now.subtract(_stageElapsedBeforePause),
    );
    _startTicker();
    _emit();
    return _snapshot!;
  }

  CookProgramExecutionSnapshot stop() {
    _ticker?.cancel();
    final current = _requireSnapshot();
    _snapshot = current.copyWith(status: CookProgramExecutionStatus.stopped);
    _emit();
    return _snapshot!;
  }

  CookProgramExecutionSnapshot completeCurrentStage() {
    _advanceStage();
    return _requireSnapshot();
  }

  CookProgramExecutionSnapshot onTemperatureUpdate(double currentTemperature) {
    final current = _requireSnapshot();
    final stage = current.currentStage;
    if (stage == null || current.targetReached) {
      return current;
    }

    if (currentTemperature >= stage.targetTemperature) {
      final alert = CookProgramAlert(
        type: CookProgramAlertType.targetReached,
        message:
            'Stage ${current.currentStageIndex + 1} reached ${stage.targetTemperature.toStringAsFixed(0)}°F',
        stageIndex: current.currentStageIndex,
        timestamp: DateTime.now(),
      );
      _notify(alert);
      _snapshot = current.copyWith(
        targetReached: true,
        alerts: [...current.alerts, alert],
      );
      _emit();
    }

    return _snapshot!;
  }

  void dispose() {
    _ticker?.cancel();
    _controller.close();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = _requireSnapshot();
    if (current.status != CookProgramExecutionStatus.running) {
      return;
    }

    final now = DateTime.now();
    final startedAt = current.startedAt ?? now;
    final stageStartedAt = current.stageStartedAt ?? now;
    final currentStage = current.currentStage;

    if (currentStage == null) {
      _snapshot = current.copyWith(status: CookProgramExecutionStatus.completed);
      _emit();
      return;
    }

    final elapsed = now.difference(startedAt);
    final stageElapsed = now.difference(stageStartedAt);
    final remaining = currentStage.duration - stageElapsed;

    if (remaining <= Duration.zero) {
      _advanceStage();
      return;
    }

    _snapshot = current.copyWith(
      elapsed: elapsed,
      stageElapsed: stageElapsed,
      stageRemaining: remaining,
    );
    _emit();
  }

  void _advanceStage() {
    final current = _requireSnapshot();
    final stage = current.currentStage;
    if (stage == null) {
      return;
    }

    final alert = CookProgramAlert(
      type: CookProgramAlertType.stageCompleted,
      message: 'Stage ${current.currentStageIndex + 1} complete',
      stageIndex: current.currentStageIndex,
      timestamp: DateTime.now(),
    );
    final alerts = [...current.alerts, alert];
    _notify(alert);

    final nextIndex = current.currentStageIndex + 1;
    if (nextIndex >= current.program.stages.length) {
      _ticker?.cancel();
      final completedProgram =
          current.program.copyWith(status: CookProgramStatus.completed);
      final timerAlert = CookProgramAlert(
        type: CookProgramAlertType.timerExpired,
        message: '${current.program.name} finished',
        stageIndex: current.currentStageIndex,
        timestamp: DateTime.now(),
      );
      _notify(timerAlert);
      _snapshot = current.copyWith(
        program: completedProgram,
        status: CookProgramExecutionStatus.completed,
        alerts: [...alerts, timerAlert],
        stageRemaining: Duration.zero,
        targetReached: false,
      );
      _emit();
      return;
    }

    final now = DateTime.now();
    _snapshot = current.copyWith(
      currentStageIndex: nextIndex,
      stageStartedAt: now,
      stageElapsed: Duration.zero,
      stageRemaining: current.program.stages[nextIndex].duration,
      alerts: alerts,
      targetReached: false,
    );
    _emit();
  }

  void _emit() {
    final snapshot = _snapshot;
    if (snapshot != null && !_controller.isClosed) {
      _controller.add(snapshot);
    }
  }

  void _notify(CookProgramAlert alert) {
    _notifications.push(
      title: 'Cook Program Alert',
      message: alert.message,
      type: AppNotificationType.alert,
    );
  }

  CookProgramExecutionSnapshot _requireSnapshot() {
    final snapshot = _snapshot;
    if (snapshot == null) {
      throw StateError('Cook program execution has not started.');
    }
    return snapshot;
  }
}
