// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleModelAdapter extends TypeAdapter<ScheduleModel> {
  @override
  final int typeId = 0;

  @override
  ScheduleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduleModel(
      name: fields[0] as String,
      Start: fields[1] as DateTime,
      End: fields[2] as DateTime,
      isSilentOrVibration: fields[3] as bool,
      isTaskActivated: fields[4] as bool,
      quickTime: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.Start)
      ..writeByte(2)
      ..write(obj.End)
      ..writeByte(3)
      ..write(obj.isSilentOrVibration)
      ..writeByte(4)
      ..write(obj.isTaskActivated)
      ..writeByte(5)
      ..write(obj.quickTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
