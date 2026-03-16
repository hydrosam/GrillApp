import 'package:equatable/equatable.dart';

import '../entities/temperature_reading.dart';

enum GrillOpenStatus { closed, open, resuming }

class GrillOpenSnapshot extends Equatable {
  final GrillOpenStatus status;
  final TemperatureReading? lastReading;
  final double dropAmount;
  final double riseAmount;
  final DateTime? openedAt;
  final double minimumTemperature;

  const GrillOpenSnapshot({
    required this.status,
    required this.lastReading,
    required this.dropAmount,
    required this.riseAmount,
    required this.openedAt,
    required this.minimumTemperature,
  });

  factory GrillOpenSnapshot.initial() {
    return const GrillOpenSnapshot(
      status: GrillOpenStatus.closed,
      lastReading: null,
      dropAmount: 0,
      riseAmount: 0,
      openedAt: null,
      minimumTemperature: double.infinity,
    );
  }

  @override
  List<Object?> get props =>
      [status, lastReading, dropAmount, riseAmount, openedAt, minimumTemperature];

  GrillOpenSnapshot copyWith({
    GrillOpenStatus? status,
    TemperatureReading? lastReading,
    double? dropAmount,
    double? riseAmount,
    DateTime? openedAt,
    double? minimumTemperature,
  }) {
    return GrillOpenSnapshot(
      status: status ?? this.status,
      lastReading: lastReading ?? this.lastReading,
      dropAmount: dropAmount ?? this.dropAmount,
      riseAmount: riseAmount ?? this.riseAmount,
      openedAt: openedAt ?? this.openedAt,
      minimumTemperature: minimumTemperature ?? this.minimumTemperature,
    );
  }
}

class GrillOpenDetector {
  GrillOpenDetector({
    this.dropThreshold = 5,
    this.detectionWindow = const Duration(seconds: 30),
    this.resumeRiseThreshold = 1,
  });

  final double dropThreshold;
  final Duration detectionWindow;
  final double resumeRiseThreshold;
  final List<TemperatureReading> _history = <TemperatureReading>[];

  GrillOpenSnapshot process(TemperatureReading reading) {
    if (reading.type != ProbeType.grill) {
      return _current.copyWith(lastReading: reading);
    }

    _history.add(reading);
    _history.removeWhere(
      (entry) => reading.timestamp.difference(entry.timestamp) > detectionWindow,
    );

    final baseline = _history.isEmpty ? reading : _history.first;
    final dropAmount = baseline.temperature - reading.temperature;

    if (_current.status != GrillOpenStatus.open && dropAmount > dropThreshold) {
      _current = GrillOpenSnapshot(
        status: GrillOpenStatus.open,
        lastReading: reading,
        dropAmount: dropAmount,
        riseAmount: 0,
        openedAt: reading.timestamp,
        minimumTemperature: reading.temperature,
      );
      return _current;
    }

    if (_current.status == GrillOpenStatus.open) {
      final minimumTemperature =
          reading.temperature < _current.minimumTemperature
              ? reading.temperature
              : _current.minimumTemperature;
      final riseAmount = reading.temperature - minimumTemperature;
      if (riseAmount >= resumeRiseThreshold) {
        _current = GrillOpenSnapshot(
          status: GrillOpenStatus.resuming,
          lastReading: reading,
          dropAmount: _current.dropAmount,
          riseAmount: riseAmount,
          openedAt: _current.openedAt,
          minimumTemperature: minimumTemperature,
        );
        return _current;
      }

      _current = _current.copyWith(
        lastReading: reading,
        minimumTemperature: minimumTemperature,
      );
      return _current;
    }

    if (_current.status == GrillOpenStatus.resuming) {
      _current = GrillOpenSnapshot(
        status: GrillOpenStatus.closed,
        lastReading: reading,
        dropAmount: 0,
        riseAmount: 0,
        openedAt: null,
        minimumTemperature: reading.temperature,
      );
      return _current;
    }

    _current = GrillOpenSnapshot(
      status: GrillOpenStatus.closed,
      lastReading: reading,
      dropAmount: 0,
      riseAmount: 0,
      openedAt: null,
      minimumTemperature: reading.temperature,
    );
    return _current;
  }

  GrillOpenSnapshot manualResume(TemperatureReading? reading) {
    _current = GrillOpenSnapshot(
      status: GrillOpenStatus.closed,
      lastReading: reading,
      dropAmount: 0,
      riseAmount: 0,
      openedAt: null,
      minimumTemperature: reading?.temperature ?? double.infinity,
    );
    return _current;
  }

  void reset() {
    _history.clear();
    _current = GrillOpenSnapshot.initial();
  }

  GrillOpenSnapshot _current = GrillOpenSnapshot.initial();
}
