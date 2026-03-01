import 'package:equatable/equatable.dart';

/// iKamand device command model
/// 
/// Represents a command to send to an iKamand device via HTTP.
/// Can set fan speed and/or target temperature.
/// 
/// Requirements: 9.2, 9.3
class IKamandCommand extends Equatable {
  final int? fanSpeed; // 0-100 percentage
  final double? targetTemp; // Fahrenheit

  const IKamandCommand({
    this.fanSpeed,
    this.targetTemp,
  });

  @override
  List<Object?> get props => [fanSpeed, targetTemp];

  /// Convert to HTTP request body JSON
  /// 
  /// Expected JSON format:
  /// {
  ///   "fan_speed": 50,
  ///   "target_temp": 275.0
  /// }
  /// 
  /// Only includes non-null fields in the output.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    
    if (fanSpeed != null) {
      json['fan_speed'] = fanSpeed;
    }
    
    if (targetTemp != null) {
      json['target_temp'] = targetTemp;
    }
    
    return json;
  }

  factory IKamandCommand.fromJson(Map<String, dynamic> json) {
    return IKamandCommand(
      fanSpeed: json['fan_speed'] as int?,
      targetTemp: json['target_temp'] != null 
          ? (json['target_temp'] as num).toDouble() 
          : null,
    );
  }

  /// Create a command to set fan speed
  factory IKamandCommand.setFanSpeed(int speed) {
    assert(speed >= 0 && speed <= 100, 'Fan speed must be between 0 and 100');
    return IKamandCommand(fanSpeed: speed);
  }

  /// Create a command to set target temperature
  factory IKamandCommand.setTargetTemp(double temp) {
    assert(temp >= 32 && temp <= 1000, 'Temperature must be between 32°F and 1000°F');
    return IKamandCommand(targetTemp: temp);
  }

  /// Create a command to set both fan speed and target temperature
  factory IKamandCommand.setBoth(int speed, double temp) {
    assert(speed >= 0 && speed <= 100, 'Fan speed must be between 0 and 100');
    assert(temp >= 32 && temp <= 1000, 'Temperature must be between 32°F and 1000°F');
    return IKamandCommand(fanSpeed: speed, targetTemp: temp);
  }
}
