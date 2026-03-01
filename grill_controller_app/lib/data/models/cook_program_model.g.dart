// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cook_program_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CookProgramModelAdapter extends TypeAdapter<CookProgramModel> {
  @override
  final int typeId = 2;

  @override
  CookProgramModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CookProgramModel(
      id: fields[0] as String,
      name: fields[1] as String,
      stages: (fields[2] as List).cast<CookStageModel>(),
      status: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CookProgramModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.stages)
      ..writeByte(3)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookProgramModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CookStageModelAdapter extends TypeAdapter<CookStageModel> {
  @override
  final int typeId = 3;

  @override
  CookStageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CookStageModel(
      targetTemperature: fields[0] as double,
      durationSeconds: fields[1] as int,
      alertOnComplete: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CookStageModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.targetTemperature)
      ..writeByte(1)
      ..write(obj.durationSeconds)
      ..writeByte(2)
      ..write(obj.alertOnComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookStageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
