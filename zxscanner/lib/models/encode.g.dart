// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encode.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EncodeAdapter extends TypeAdapter<Encode> {
  @override
  final int typeId = 1;

  @override
  Encode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Encode()
      ..isValid = fields[0] as bool?
      ..format = fields[1] as int?
      ..text = fields[2] as String?
      ..data = fields[3] as Uint8List?
      ..length = fields[4] as int?;
  }

  @override
  void write(BinaryWriter writer, Encode obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.isValid)
      ..writeByte(1)
      ..write(obj.format)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.data)
      ..writeByte(4)
      ..write(obj.length);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
