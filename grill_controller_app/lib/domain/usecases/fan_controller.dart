import 'package:equatable/equatable.dart';

import '../../core/error/app_exception.dart';
import '../entities/grill_device.dart';

enum FanControlMode { automatic, manual, grillOpen }

class FanControlSnapshot extends Equatable {
  final String deviceId;
  final double targetTemperature;
  final double currentTemperature;
  final double temperatureDelta;
  final int fanSpeed;
  final FanControlMode mode;
  final String grillType;
  final DeviceType deviceType;
  final DateTime updatedAt;
  final Map<String, double> curveAdjustments;

  const FanControlSnapshot({
    required this.deviceId,
    required this.targetTemperature,
    required this.currentTemperature,
    required this.temperatureDelta,
    required this.fanSpeed,
    required this.mode,
    required this.grillType,
    required this.deviceType,
    required this.updatedAt,
    required this.curveAdjustments,
  });

  bool get isAutomatic => mode == FanControlMode.automatic;

  @override
  List<Object?> get props => [
        deviceId,
        targetTemperature,
        currentTemperature,
        temperatureDelta,
        fanSpeed,
        mode,
        grillType,
        deviceType,
        updatedAt,
        curveAdjustments,
      ];

  FanControlSnapshot copyWith({
    double? targetTemperature,
    double? currentTemperature,
    double? temperatureDelta,
    int? fanSpeed,
    FanControlMode? mode,
    String? grillType,
    DeviceType? deviceType,
    DateTime? updatedAt,
    Map<String, double>? curveAdjustments,
  }) {
    return FanControlSnapshot(
      deviceId: deviceId,
      targetTemperature: targetTemperature ?? this.targetTemperature,
      currentTemperature: currentTemperature ?? this.currentTemperature,
      temperatureDelta: temperatureDelta ?? this.temperatureDelta,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      mode: mode ?? this.mode,
      grillType: grillType ?? this.grillType,
      deviceType: deviceType ?? this.deviceType,
      updatedAt: updatedAt ?? this.updatedAt,
      curveAdjustments: curveAdjustments ?? this.curveAdjustments,
    );
  }
}

class FanController {
  static const double minTemperature = 32;
  static const double maxTemperature = 1000;

  double calculateTemperatureDelta({
    required double currentTemperature,
    required double targetTemperature,
  }) {
    _validateTemperature(targetTemperature);
    return targetTemperature - currentTemperature;
  }

  int calculateFanSpeed({
    required double currentTemperature,
    required double targetTemperature,
    required String grillType,
    required DeviceType deviceType,
    Map<String, double> curveAdjustments = const {},
  }) {
    final delta = calculateTemperatureDelta(
      currentTemperature: currentTemperature,
      targetTemperature: targetTemperature,
    );

    if (delta <= 0) {
      return 0;
    }

    final baseSpeed = switch (delta) {
      <= 5 => 18,
      <= 15 => 35,
      <= 30 => 55,
      <= 60 => 78,
      _ => 100,
    };

    final grillMultiplier = switch (grillType.toLowerCase()) {
      'ceramic' => 0.80,
      'kettle' => 1.10,
      'offset' => 0.92,
      'pellet' => 0.70,
      'smoker' => 0.88,
      _ => 1.0,
    };

    final deviceMultiplier = switch (deviceType) {
      DeviceType.ikamand => 1.0,
      DeviceType.unknown => 0.92,
    };

    final userMultiplier = curveAdjustments['multiplier'] ?? 1.0;
    final lowDeltaBoost = curveAdjustments['lowDeltaBoost'] ?? 0.0;
    final highDeltaBoost = curveAdjustments['highDeltaBoost'] ?? 0.0;

    var speed = baseSpeed * grillMultiplier * deviceMultiplier * userMultiplier;
    if (delta <= 10) {
      speed += lowDeltaBoost;
    } else if (delta >= 30) {
      speed += highDeltaBoost;
    }

    return speed.round().clamp(0, 100);
  }

  FanControlSnapshot automatic({
    required String deviceId,
    required double currentTemperature,
    required double targetTemperature,
    required String grillType,
    required DeviceType deviceType,
    Map<String, double> curveAdjustments = const {},
  }) {
    final delta = calculateTemperatureDelta(
      currentTemperature: currentTemperature,
      targetTemperature: targetTemperature,
    );

    return FanControlSnapshot(
      deviceId: deviceId,
      targetTemperature: targetTemperature,
      currentTemperature: currentTemperature,
      temperatureDelta: delta,
      fanSpeed: calculateFanSpeed(
        currentTemperature: currentTemperature,
        targetTemperature: targetTemperature,
        grillType: grillType,
        deviceType: deviceType,
        curveAdjustments: curveAdjustments,
      ),
      mode: FanControlMode.automatic,
      grillType: grillType,
      deviceType: deviceType,
      updatedAt: DateTime.now(),
      curveAdjustments: Map<String, double>.unmodifiable(curveAdjustments),
    );
  }

  FanControlSnapshot manual({
    required FanControlSnapshot current,
    required int fanSpeed,
  }) {
    return current.copyWith(
      fanSpeed: fanSpeed.clamp(0, 100),
      mode: FanControlMode.manual,
      updatedAt: DateTime.now(),
    );
  }

  FanControlSnapshot grillOpen({
    required FanControlSnapshot current,
  }) {
    return current.copyWith(
      fanSpeed: 0,
      mode: FanControlMode.grillOpen,
      updatedAt: DateTime.now(),
    );
  }

  FanControlSnapshot resumeAutomatic({
    required FanControlSnapshot current,
    double? currentTemperature,
  }) {
    return automatic(
      deviceId: current.deviceId,
      currentTemperature: currentTemperature ?? current.currentTemperature,
      targetTemperature: current.targetTemperature,
      grillType: current.grillType,
      deviceType: current.deviceType,
      curveAdjustments: current.curveAdjustments,
    );
  }

  void _validateTemperature(double temperature) {
    if (temperature < minTemperature || temperature > maxTemperature) {
      throw ValidationException(
        'Temperature must be between $minTemperature°F and $maxTemperature°F',
      );
    }
  }
}
