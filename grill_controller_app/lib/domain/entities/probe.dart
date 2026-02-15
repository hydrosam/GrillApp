import 'package:equatable/equatable.dart';
import 'temperature_reading.dart';

/// Probe configuration
class Probe extends Equatable {
  final String id;
  final ProbeType type;
  final bool isActive;
  final double? targetTemperature;

  const Probe({
    required this.id,
    required this.type,
    required this.isActive,
    this.targetTemperature,
  });

  @override
  List<Object?> get props => [id, type, isActive, targetTemperature];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'isActive': isActive,
      'targetTemperature': targetTemperature,
    };
  }

  factory Probe.fromJson(Map<String, dynamic> json) {
    return Probe(
      id: json['id'] as String,
      type: ProbeType.values.firstWhere((e) => e.name == json['type']),
      isActive: json['isActive'] as bool,
      targetTemperature: json['targetTemperature'] as double?,
    );
  }
}
