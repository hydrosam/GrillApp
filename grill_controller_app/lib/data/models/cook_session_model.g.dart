// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cook_session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CookSessionModelAdapter extends TypeAdapter<CookSessionModel> {
  @override
  final int typeId = 1;

  @override
  CookSessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CookSessionModel(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      deviceId: fields[3] as String,
      notes: fields[4] as String?,
      programId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CookSessionModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.deviceId)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.programId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookSessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
