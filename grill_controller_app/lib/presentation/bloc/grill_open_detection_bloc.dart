import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/temperature_reading.dart';
import '../../domain/usecases/grill_open_detector.dart';

abstract class GrillOpenDetectionEvent extends Equatable {
  const GrillOpenDetectionEvent();

  @override
  List<Object?> get props => [];
}

class TemperatureUpdate extends GrillOpenDetectionEvent {
  final TemperatureReading reading;

  const TemperatureUpdate(this.reading);

  @override
  List<Object?> get props => [reading];
}

class ManualResume extends GrillOpenDetectionEvent {
  const ManualResume();
}

abstract class GrillOpenDetectionState extends Equatable {
  final GrillOpenSnapshot snapshot;

  const GrillOpenDetectionState(this.snapshot);

  @override
  List<Object?> get props => [snapshot];
}

class GrillClosed extends GrillOpenDetectionState {
  const GrillClosed(super.snapshot);
}

class GrillOpen extends GrillOpenDetectionState {
  const GrillOpen(super.snapshot);
}

class GrillResuming extends GrillOpenDetectionState {
  const GrillResuming(super.snapshot);
}

class GrillOpenDetectionBloc
    extends Bloc<GrillOpenDetectionEvent, GrillOpenDetectionState> {
  GrillOpenDetectionBloc({required GrillOpenDetector detector})
      : _detector = detector,
        super(GrillClosed(GrillOpenSnapshot.initial())) {
    on<TemperatureUpdate>(_onTemperatureUpdate);
    on<ManualResume>(_onManualResume);
  }

  final GrillOpenDetector _detector;

  void _onTemperatureUpdate(
    TemperatureUpdate event,
    Emitter<GrillOpenDetectionState> emit,
  ) {
    final snapshot = _detector.process(event.reading);
    emit(_mapSnapshot(snapshot));
  }

  void _onManualResume(
    ManualResume event,
    Emitter<GrillOpenDetectionState> emit,
  ) {
    final currentReading = state.snapshot.lastReading;
    final snapshot = _detector.manualResume(currentReading);
    emit(_mapSnapshot(snapshot));
  }

  GrillOpenDetectionState _mapSnapshot(GrillOpenSnapshot snapshot) {
    return switch (snapshot.status) {
      GrillOpenStatus.open => GrillOpen(snapshot),
      GrillOpenStatus.resuming => GrillResuming(snapshot),
      GrillOpenStatus.closed => GrillClosed(snapshot),
    };
  }
}
