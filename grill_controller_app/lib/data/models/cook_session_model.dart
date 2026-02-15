import 'package:hive/hive.dart';

part 'cook_session_model.g.dart';

@HiveType(typeId: 1)
class CookSessionModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime startTime;

  @HiveField(2)
  DateTime? endTime;

  @HiveField(3)
  String deviceId;

  @HiveField(4)
  String? notes;

  @HiveField(5)
  String? programId;

  CookSessionModel({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.deviceId,
    this.notes,
    this.programId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'deviceId': deviceId,
      'notes': notes,
      'programId': programId,
    };
  }

  factory CookSessionModel.fromJson(Map<String, dynamic> json) {
    return CookSessionModel(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String) 
          : null,
      deviceId: json['deviceId'] as String,
      notes: json['notes'] as String?,
      programId: json['programId'] as String?,
    );
  }
}
