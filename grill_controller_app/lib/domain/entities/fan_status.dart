import 'package:equatable/equatable.dart';

/// Fan control status
class FanStatus extends Equatable {
  final int speed; // 0-100 percentage
  final bool isAutomatic;
  final DateTime lastUpdate;

  const FanStatus({
    required this.speed,
    required this.isAutomatic,
    required this.lastUpdate,
  });

  @override
  List<Object?> get props => [speed, isAutomatic, lastUpdate];

  Map<String, dynamic> toJson() {
    return {
      'speed': speed,
      'isAutomatic': isAutomatic,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }

  factory FanStatus.fromJson(Map<String, dynamic> json) {
    return FanStatus(
      speed: json['speed'] as int,
      isAutomatic: json['isAutomatic'] as bool,
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
    );
  }
}
