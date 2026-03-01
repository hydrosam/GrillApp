import 'package:hive/hive.dart';
import '../../domain/entities/cook_program.dart';

part 'cook_program_model.g.dart';

/// Hive model for CookProgram
/// 
/// Stores cook programs in local storage with Hive.
/// Type ID: 2
@HiveType(typeId: 2)
class CookProgramModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<CookStageModel> stages;

  @HiveField(3)
  String status;

  CookProgramModel({
    required this.id,
    required this.name,
    required this.stages,
    required this.status,
  });

  /// Convert from domain entity
  factory CookProgramModel.fromEntity(CookProgram program) {
    return CookProgramModel(
      id: program.id,
      name: program.name,
      stages: program.stages
          .map((stage) => CookStageModel.fromEntity(stage))
          .toList(),
      status: program.status.name,
    );
  }

  /// Convert to domain entity
  CookProgram toEntity() {
    return CookProgram(
      id: id,
      name: name,
      stages: stages.map((stage) => stage.toEntity()).toList(),
      status: CookProgramStatus.values.firstWhere((e) => e.name == status),
    );
  }
}

/// Hive model for CookStage
@HiveType(typeId: 3)
class CookStageModel {
  @HiveField(0)
  double targetTemperature;

  @HiveField(1)
  int durationSeconds;

  @HiveField(2)
  bool alertOnComplete;

  CookStageModel({
    required this.targetTemperature,
    required this.durationSeconds,
    required this.alertOnComplete,
  });

  /// Convert from domain entity
  factory CookStageModel.fromEntity(CookStage stage) {
    return CookStageModel(
      targetTemperature: stage.targetTemperature,
      durationSeconds: stage.duration.inSeconds,
      alertOnComplete: stage.alertOnComplete,
    );
  }

  /// Convert to domain entity
  CookStage toEntity() {
    return CookStage(
      targetTemperature: targetTemperature,
      duration: Duration(seconds: durationSeconds),
      alertOnComplete: alertOnComplete,
    );
  }
}
