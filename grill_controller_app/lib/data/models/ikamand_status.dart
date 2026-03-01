import 'package:equatable/equatable.dart';

/// iKamand device status model
/// 
/// Represents the status response from an iKamand device via HTTP.
/// Includes temperature readings from all probes, fan speed, and target temperature.
/// 
/// Requirements: 9.2, 9.3
class IKamandStatus extends Equatable {
  final double grillTemp;
  final double? food1Temp;
  final double? food2Temp;
  final double? food3Temp;
  final int fanSpeed; // 0-100 percentage
  final double targetTemp;

  const IKamandStatus({
    required this.grillTemp,
    this.food1Temp,
    this.food2Temp,
    this.food3Temp,
    required this.fanSpeed,
    required this.targetTemp,
  });

  @override
  List<Object?> get props => [
        grillTemp,
        food1Temp,
        food2Temp,
        food3Temp,
        fanSpeed,
        targetTemp,
      ];

  /// Parse from HTTP JSON response
  /// 
  /// Expected JSON format:
  /// {
  ///   "grill_temp": 250.5,
  ///   "food1_temp": 165.0,
  ///   "food2_temp": null,
  ///   "food3_temp": null,
  ///   "fan_speed": 45,
  ///   "target_temp": 275.0
  /// }
  factory IKamandStatus.fromJson(Map<String, dynamic> json) {
    return IKamandStatus(
      grillTemp: (json['grill_temp'] as num).toDouble(),
      food1Temp: json['food1_temp'] != null 
          ? (json['food1_temp'] as num).toDouble() 
          : null,
      food2Temp: json['food2_temp'] != null 
          ? (json['food2_temp'] as num).toDouble() 
          : null,
      food3Temp: json['food3_temp'] != null 
          ? (json['food3_temp'] as num).toDouble() 
          : null,
      fanSpeed: json['fan_speed'] as int,
      targetTemp: (json['target_temp'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grill_temp': grillTemp,
      'food1_temp': food1Temp,
      'food2_temp': food2Temp,
      'food3_temp': food3Temp,
      'fan_speed': fanSpeed,
      'target_temp': targetTemp,
    };
  }
}
