import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/temperature_repository_impl.dart';
import '../../domain/entities/temperature_reading.dart';
import '../../domain/repositories/temperature_repository.dart';

abstract class TemperatureMonitorEvent extends Equatable {
  const TemperatureMonitorEvent();

  @override
  List<Object?> get props => [];
}

class StartMonitoring extends TemperatureMonitorEvent {
  final String deviceId;

  const StartMonitoring(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

class StopMonitoring extends TemperatureMonitorEvent {
  const StopMonitoring();
}

class UpdateReading extends TemperatureMonitorEvent {
  final TemperatureReading reading;

  const UpdateReading(this.reading);

  @override
  List<Object?> get props => [reading];
}

class TemperatureMonitorFailed extends TemperatureMonitorEvent {
  final String message;

  const TemperatureMonitorFailed(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class TemperatureMonitorState extends Equatable {
  final String? deviceId;
  final List<TemperatureReading> readings;
  final String? message;

  const TemperatureMonitorState({
    required this.deviceId,
    required this.readings,
    this.message,
  });

  Map<ProbeType, TemperatureReading> get latestReadings {
    final latest = <ProbeType, TemperatureReading>{};
    for (final reading in readings) {
      latest[reading.type] = reading;
    }
    return latest;
  }

  List<TemperatureReading> readingsFor(ProbeType type) {
    return readings.where((reading) => reading.type == type).toList();
  }

  @override
  List<Object?> get props => [deviceId, readings, message];
}

class TemperatureMonitorIdle extends TemperatureMonitorState {
  const TemperatureMonitorIdle({
    String? deviceId,
    List<TemperatureReading> readings = const [],
    String? message,
  }) : super(deviceId: deviceId, readings: readings, message: message);
}

class TemperatureMonitoring extends TemperatureMonitorState {
  const TemperatureMonitoring({
    required super.deviceId,
    required super.readings,
    super.message,
  });
}

class TemperatureMonitorError extends TemperatureMonitorState {
  const TemperatureMonitorError({
    required super.deviceId,
    required super.readings,
    required super.message,
  });
}

class TemperatureMonitorBloc
    extends Bloc<TemperatureMonitorEvent, TemperatureMonitorState> {
  TemperatureMonitorBloc({required TemperatureRepository repository})
      : _repository = repository,
        super(const TemperatureMonitorIdle()) {
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
    on<UpdateReading>(_onUpdateReading);
    on<TemperatureMonitorFailed>(_onMonitoringFailed);
  }

  final TemperatureRepository _repository;
  StreamSubscription<TemperatureReading>? _subscription;

  Future<void> _onStartMonitoring(
    StartMonitoring event,
    Emitter<TemperatureMonitorState> emit,
  ) async {
    await _subscription?.cancel();

    final existingReadings =
        state.deviceId == event.deviceId ? state.readings : <TemperatureReading>[];
    emit(TemperatureMonitoring(
      deviceId: event.deviceId,
      readings: existingReadings,
    ));

    try {
      final history = await _repository.getHistory(
        event.deviceId,
        DateTime.now().subtract(const Duration(hours: 6)),
        DateTime.now(),
      );

      emit(TemperatureMonitoring(
        deviceId: event.deviceId,
        readings: history,
      ));
    } catch (_) {
      // History is optional at startup; live monitoring can proceed without it.
    }

    _subscription = _repository.watchTemperatures(event.deviceId).listen(
      (reading) => add(UpdateReading(reading)),
      onError: (error) => add(TemperatureMonitorFailed(error.toString())),
    );
  }

  Future<void> _onStopMonitoring(
    StopMonitoring event,
    Emitter<TemperatureMonitorState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = null;
    final currentDeviceId = state.deviceId;
    if (_repository is TemperatureRepositoryImpl && currentDeviceId != null) {
      (_repository as TemperatureRepositoryImpl).stopWatching(currentDeviceId);
    }
    emit(TemperatureMonitorIdle(
      deviceId: currentDeviceId,
      readings: state.readings,
    ));
  }

  void _onUpdateReading(
    UpdateReading event,
    Emitter<TemperatureMonitorState> emit,
  ) {
    final updatedReadings = [...state.readings, event.reading];
    const maxReadings = 600;
    final trimmed = updatedReadings.length > maxReadings
        ? updatedReadings.sublist(updatedReadings.length - maxReadings)
        : updatedReadings;

    emit(TemperatureMonitoring(
      deviceId: state.deviceId,
      readings: trimmed,
    ));
  }

  void _onMonitoringFailed(
    TemperatureMonitorFailed event,
    Emitter<TemperatureMonitorState> emit,
  ) {
    emit(TemperatureMonitorError(
      deviceId: state.deviceId,
      readings: state.readings,
      message: event.message,
    ));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
