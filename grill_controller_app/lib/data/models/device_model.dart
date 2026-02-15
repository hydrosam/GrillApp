import 'package:hive/hive.dart';

part 'device_model.g.dart';

@HiveType(typeId: 0)
class DeviceModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type;

  @HiveField(3)
  String? lastKnownIp;

  @HiveField(4)
  Map<String, dynamic>? configuration;

  DeviceModel({
    required this.id,
    required this.name,
    required this.type,
    this.lastKnownIp,
    this.configuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'lastKnownIp': lastKnownIp,
      'configuration': configuration,
    };
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      lastKnownIp: json['lastKnownIp'] as String?,
      configuration: json['configuration'] as Map<String, dynamic>?,
    );
  }
}
