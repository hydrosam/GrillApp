import 'package:equatable/equatable.dart';
import 'temperature_reading.dart';
import 'cook_program.dart';

/// Cook session with history and notes
class CookSession extends Equatable {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final String deviceId;
  final List<TemperatureReading> readings;
  final String? notes;
  final CookProgram? program;

  const CookSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.deviceId,
    required this.readings,
    this.notes,
    this.program,
  });

  @override
  List<Object?> get props => [id, startTime, endTime, deviceId, readings, notes, program];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'deviceId': deviceId,
      'readings': readings.map((r) => r.toJson()).toList(),
      'notes': notes,
      'program': program?.toJson(),
    };
  }

  factory CookSession.fromJson(Map<String, dynamic> json) {
    return CookSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      deviceId: json['deviceId'] as String,
      readings: (json['readings'] as List)
          .map((r) => TemperatureReading.fromJson(r as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      program: json['program'] != null 
          ? CookProgram.fromJson(json['program'] as Map<String, dynamic>)
          : null,
    );
  }
}
