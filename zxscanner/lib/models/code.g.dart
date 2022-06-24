// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'code.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CodeAdapter extends TypeAdapter<Code> {
  @override
  final int typeId = 0;

  @override
  Code read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Code()
      ..isValid = fields[0] as bool?
      ..format = fields[1] as int?
      ..text = fields[2] as String?;
  }

  @override
  void write(BinaryWriter writer, Code obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.isValid)
      ..writeByte(1)
      ..write(obj.format)
      ..writeByte(2)
      ..write(obj.text);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
