// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nemaz_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NemazModelAdapter extends TypeAdapter<NemazModel> {
  @override
  final int typeId = 2;

  @override
  NemazModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NemazModel(
      FajarStart: fields[0] as DateTime,
      FajarEnd: fields[1] as DateTime,
      ZoharStart: fields[2] as DateTime,
      ZoharEnd: fields[3] as DateTime,
      AsarStart: fields[4] as DateTime,
      AsarEnd: fields[5] as DateTime,
      MagribStart: fields[6] as DateTime,
      MagribEnd: fields[7] as DateTime,
      IshaStart: fields[8] as DateTime,
      IshaEnd: fields[9] as DateTime,
      isSilentOrVibration: fields[10] as bool,
      isFajarTaskActivated: fields[11] as bool,
      isZoharTaskActivated: fields[12] as bool,
      isAsarTaskActivated: fields[13] as bool,
      isMagribTaskActivated: fields[14] as bool,
      isIshaTaskActivated: fields[15] as bool,
      forWhichMasjid: fields[16] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NemazModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.FajarStart)
      ..writeByte(1)
      ..write(obj.FajarEnd)
      ..writeByte(2)
      ..write(obj.ZoharStart)
      ..writeByte(3)
      ..write(obj.ZoharEnd)
      ..writeByte(4)
      ..write(obj.AsarStart)
      ..writeByte(5)
      ..write(obj.AsarEnd)
      ..writeByte(6)
      ..write(obj.MagribStart)
      ..writeByte(7)
      ..write(obj.MagribEnd)
      ..writeByte(8)
      ..write(obj.IshaStart)
      ..writeByte(9)
      ..write(obj.IshaEnd)
      ..writeByte(10)
      ..write(obj.isSilentOrVibration)
      ..writeByte(11)
      ..write(obj.isFajarTaskActivated)
      ..writeByte(12)
      ..write(obj.isZoharTaskActivated)
      ..writeByte(13)
      ..write(obj.isAsarTaskActivated)
      ..writeByte(14)
      ..write(obj.isMagribTaskActivated)
      ..writeByte(15)
      ..write(obj.isIshaTaskActivated)
      ..writeByte(16)
      ..write(obj.forWhichMasjid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NemazModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
