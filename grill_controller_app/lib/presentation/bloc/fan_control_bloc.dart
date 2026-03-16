import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/error_handling_middleware.dart';
import '../../domain/entities/grill_device.dart';
import '../../domain/repositories/device_repository.dart';
import '../../domain/usecases/fan_controller.dart';

abstract class FanControlEvent extends Equatable {
  const FanControlEvent();

  @override
  List<Object?> get props => [];
}

class InitializeFanControl extends FanControlEvent {
  final String deviceId;
  final double currentTemperature;
  final double targetTemperature;
  final String grillType;
  final DeviceType deviceType;
  final Map<String, double> curveAdjustments;

  const InitializeFanControl({
    required this.deviceId,
    required this.currentTemperature,
    required this.targetTemperature,
    required this.grillType,
    required this.deviceType,
    this.curveAdjustments = const {},
  });

  @override
  List<Object?> get props => [
        deviceId,
        currentTemperature,
        targetTemperature,
        grillType,
        deviceType,
        curveAdjustments,
      ];
}

class SetTargetTemperature extends FanControlEvent {
  final double targetTemperature;

  const SetTargetTemperature(this.targetTemperature);

  @override
  List<Object?> get props => [targetTemperature];
}

class SetManualSpeed extends FanControlEvent {
  final int speed;

  const SetManualSpeed(this.speed);

  @override
  List<Object?> get props => [speed];
}

class EnableAutomatic extends FanControlEvent {
  final double? currentTemperature;

  const EnableAutomatic({this.currentTemperature});

  @override
  List<Object?> get props => [currentTemperature];
}

class DisableAutomatic extends FanControlEvent {
  const DisableAutomatic();
}

class TemperatureObserved extends FanControlEvent {
  final double currentTemperature;

  const TemperatureObserved(this.currentTemperature);

  @override
  List<Object?> get props => [currentTemperature];
}

class GrillOpenStatusChanged extends FanControlEvent {
  final bool isOpen;

  const GrillOpenStatusChanged(this.isOpen);

  @override
  List<Object?> get props => [isOpen];
}

abstract class FanControlState extends Equatable {
  final FanControlSnapshot snapshot;
  final String? message;

  const FanControlState(this.snapshot, {this.message});

  @override
  List<Object?> get props => [snapshot, message];
}

class FanControlAutomatic extends FanControlState {
  const FanControlAutomatic(super.snapshot, {super.message});

  factory FanControlAutomatic.initial() {
    final controller = FanController();
    return FanControlAutomatic(
      controller.automatic(
        deviceId: 'preview',
        currentTemperature: 225,
        targetTemperature: 250,
        grillType: 'standard',
        deviceType: DeviceType.unknown,
      ),
    );
  }
}

class FanControlManual extends FanControlState {
  const FanControlManual(super.snapshot, {super.message});
}

class FanControlGrillOpen extends FanControlState {
  const FanControlGrillOpen(super.snapshot, {super.message});
}

class FanControlError extends FanControlState {
  const FanControlError(super.snapshot, {required super.message});
}

class FanControlBloc extends Bloc<FanControlEvent, FanControlState> {
  FanControlBloc({
    required FanController controller,
    required DeviceRepository deviceRepository,
    required ErrorHandlingMiddleware errorHandling,
  })  : _controller = controller,
        _deviceRepository = deviceRepository,
        _errorHandling = errorHandling,
        super(FanControlAutomatic.initial()) {
    on<InitializeFanControl>(_onInitialize);
    on<SetTargetTemperature>(_onSetTargetTemperature);
    on<SetManualSpeed>(_onSetManualSpeed);
    on<EnableAutomatic>(_onEnableAutomatic);
    on<DisableAutomatic>(_onDisableAutomatic);
    on<TemperatureObserved>(_onTemperatureObserved);
    on<GrillOpenStatusChanged>(_onGrillOpenStatusChanged);
  }

  final FanController _controller;
  final DeviceRepository _deviceRepository;
  final ErrorHandlingMiddleware _errorHandling;

  Future<void> _onInitialize(
    InitializeFanControl event,
    Emitter<FanControlState> emit,
  ) async {
    final snapshot = _controller.automatic(
      deviceId: event.deviceId,
      currentTemperature: event.currentTemperature,
      targetTemperature: event.targetTemperature,
      grillType: event.grillType,
      deviceType: event.deviceType,
      curveAdjustments: event.curveAdjustments,
    );
    emit(FanControlAutomatic(snapshot));
    await _pushAutomaticCommands(snapshot);
  }

  Future<void> _onSetTargetTemperature(
    SetTargetTemperature event,
    Emitter<FanControlState> emit,
  ) async {
    final current = state.snapshot;
    try {
      final snapshot = _controller.automatic(
        deviceId: current.deviceId,
        currentTemperature: current.currentTemperature,
        targetTemperature: event.targetTemperature,
        grillType: current.grillType,
        deviceType: current.deviceType,
        curveAdjustments: current.curveAdjustments,
      );

      emit(FanControlAutomatic(snapshot));
      if (!_isPreview(snapshot.deviceId)) {
        await _errorHandling.guard(
          () => _deviceRepository.setTargetTemperature(
            snapshot.deviceId,
            snapshot.targetTemperature,
          ),
          userMessage: 'Could not update the grill target temperature.',
        );
      }
      await _pushAutomaticCommands(snapshot);
    } catch (error) {
      emit(FanControlError(current, message: error.toString()));
    }
  }

  Future<void> _onSetManualSpeed(
    SetManualSpeed event,
    Emitter<FanControlState> emit,
  ) async {
    final current = state.snapshot;
    try {
      final snapshot = _controller.manual(current: current, fanSpeed: event.speed);
      emit(FanControlManual(snapshot));
      await _pushManualCommand(snapshot);
    } catch (error) {
      emit(FanControlError(current, message: error.toString()));
    }
  }

  void _onDisableAutomatic(
    DisableAutomatic event,
    Emitter<FanControlState> emit,
  ) {
    final current = state.snapshot;
    emit(FanControlManual(_controller.manual(
      current: current,
      fanSpeed: current.fanSpeed,
    )));
  }

  Future<void> _onEnableAutomatic(
    EnableAutomatic event,
    Emitter<FanControlState> emit,
  ) async {
    final current = state.snapshot;
    try {
      final snapshot = _controller.resumeAutomatic(
        current: current,
        currentTemperature: event.currentTemperature,
      );
      emit(FanControlAutomatic(snapshot));
      await _pushAutomaticCommands(snapshot);
    } catch (error) {
      emit(FanControlError(current, message: error.toString()));
    }
  }

  Future<void> _onTemperatureObserved(
    TemperatureObserved event,
    Emitter<FanControlState> emit,
  ) async {
    final current = state.snapshot;
    final delta = _controller.calculateTemperatureDelta(
      currentTemperature: event.currentTemperature,
      targetTemperature: current.targetTemperature,
    );

    if (current.mode == FanControlMode.automatic) {
      final snapshot = _controller.automatic(
        deviceId: current.deviceId,
        currentTemperature: event.currentTemperature,
        targetTemperature: current.targetTemperature,
        grillType: current.grillType,
        deviceType: current.deviceType,
        curveAdjustments: current.curveAdjustments,
      );
      emit(FanControlAutomatic(snapshot));
      await _pushAutomaticCommands(snapshot);
      return;
    }

    final updated = current.copyWith(
      currentTemperature: event.currentTemperature,
      temperatureDelta: delta,
      updatedAt: DateTime.now(),
    );

    switch (current.mode) {
      case FanControlMode.manual:
        emit(FanControlManual(updated));
      case FanControlMode.grillOpen:
        emit(FanControlGrillOpen(updated));
      case FanControlMode.automatic:
        emit(FanControlAutomatic(updated));
    }
  }

  Future<void> _onGrillOpenStatusChanged(
    GrillOpenStatusChanged event,
    Emitter<FanControlState> emit,
  ) async {
    final current = state.snapshot;
    try {
      if (event.isOpen) {
        final snapshot = _controller.grillOpen(current: current);
        emit(FanControlGrillOpen(snapshot));
        await _pushManualCommand(snapshot);
        return;
      }

      if (current.mode == FanControlMode.grillOpen) {
        final snapshot = _controller.resumeAutomatic(current: current);
        emit(FanControlAutomatic(snapshot));
        await _pushAutomaticCommands(snapshot);
      }
    } catch (error) {
      emit(FanControlError(current, message: error.toString()));
    }
  }

  Future<void> _pushAutomaticCommands(FanControlSnapshot snapshot) async {
    if (_isPreview(snapshot.deviceId)) {
      return;
    }

    await _errorHandling.guard(
      () => _deviceRepository.setFanSpeed(snapshot.deviceId, snapshot.fanSpeed),
      userMessage: 'Could not send the new automatic fan speed to the device.',
    );
  }

  Future<void> _pushManualCommand(FanControlSnapshot snapshot) async {
    if (_isPreview(snapshot.deviceId)) {
      return;
    }

    await _errorHandling.guard(
      () => _deviceRepository.setFanSpeed(snapshot.deviceId, snapshot.fanSpeed),
      userMessage: 'Could not send the manual fan speed to the device.',
    );
  }

  bool _isPreview(String deviceId) => deviceId == 'preview';
}
