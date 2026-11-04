// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repeated_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RepeatedModelAdapter extends TypeAdapter<RepeatedModel> {
  @override
  final int typeId = 1;

  @override
  RepeatedModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RepeatedModel(
      name: fields[0] as String,
      Start: fields[1] as DateTime,
      End: fields[2] as DateTime,
      isSilentOrVibration: fields[3] as bool,
      isTaskActivated: fields[4] as bool,
      quickTime: fields[5] as int?,
      dayInWeek: (fields[6] as List?)?.cast<dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, RepeatedModel obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.quickTime)
      ..writeByte(6)
      ..write(obj.dayInWeek);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatedModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
