import 'package:equatable/equatable.dart';

enum CookProgramStatus { idle, running, paused, completed }

/// Cook stage with target temperature and duration
class CookStage extends Equatable {
  final double targetTemperature;
  final Duration duration;
  final bool alertOnComplete;

  const CookStage({
    required this.targetTemperature,
    required this.duration,
    required this.alertOnComplete,
  });

  @override
  List<Object?> get props => [targetTemperature, duration, alertOnComplete];

  Map<String, dynamic> toJson() {
    return {
      'targetTemperature': targetTemperature,
      'duration': duration.inSeconds,
      'alertOnComplete': alertOnComplete,
    };
  }

  factory CookStage.fromJson(Map<String, dynamic> json) {
    return CookStage(
      targetTemperature: (json['targetTemperature'] as num).toDouble(),
      duration: Duration(seconds: json['duration'] as int),
      alertOnComplete: json['alertOnComplete'] as bool,
    );
  }
}

/// Cook program with multiple stages
class CookProgram extends Equatable {
  final String id;
  final String name;
  final List<CookStage> stages;
  final CookProgramStatus status;

  const CookProgram({
    required this.id,
    required this.name,
    required this.stages,
    required this.status,
  });

  @override
  List<Object?> get props => [id, name, stages, status];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stages': stages.map((s) => s.toJson()).toList(),
      'status': status.name,
    };
  }

  factory CookProgram.fromJson(Map<String, dynamic> json) {
    return CookProgram(
      id: json['id'] as String,
      name: json['name'] as String,
      stages: (json['stages'] as List)
          .map((s) => CookStage.fromJson(s as Map<String, dynamic>))
          .toList(),
      status: CookProgramStatus.values.firstWhere((e) => e.name == json['status']),
    );
  }
}
