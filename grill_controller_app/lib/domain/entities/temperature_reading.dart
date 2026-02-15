import 'package:equatable/equatable.dart';

enum ProbeType { grill, food1, food2, food3 }

/// Temperature reading with timestamp
class TemperatureReading extends Equatable {
  final String probeId;
  final double temperature; // Fahrenheit
  final DateTime timestamp;
  final ProbeType type;

  const TemperatureReading({
    required this.probeId,
    required this.temperature,
    required this.timestamp,
    required this.type,
  });

  @override
  List<Object?> get props => [probeId, temperature, timestamp, type];

  Map<String, dynamic> toJson() {
    return {
      'probeId': probeId,
      'temperature': temperature,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
    };
  }

  factory TemperatureReading.fromJson(Map<String, dynamic> json) {
    return TemperatureReading(
      probeId: json['probeId'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: ProbeType.values.firstWhere((e) => e.name == json['type']),
    );
  }
}
