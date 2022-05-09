import 'package:flutter_zxing_example/models/models.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DbService {
  DbService._privateConstructor();

  static final DbService instance = DbService._privateConstructor();

  Future<void> initializeApp() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CodeAdapter());
    Hive.registerAdapter(EncodeAdapter());

    await Hive.openBox<Code>('codes');
    await Hive.openBox<Encode>('encodes');
  }

  Box<Code> getCodes() => Hive.box<Code>('codes');

  Future deleteCodes() async {
    var items = getCodes();
    await items.deleteAll(items.keys);
    return;
  }

  Future addCode(Code value) async {
    var items = getCodes();
    if (!items.values.contains(value)) {
      return items.add(value);
    }
    return;
  }

  Future<void> deleteCode(Code value) async {
    var items = getCodes();
    await items.delete(value.key);
    return;
  }

  Box<Encode> getEncodes() => Hive.box<Encode>('encodes');

  Future deleteEncodes() async {
    var items = getEncodes();
    await items.deleteAll(items.keys);
    return;
  }

  Future addEncode(Encode value) async {
    var items = getEncodes();
    if (!items.values.contains(value)) {
      return items.add(value);
    }
    return;
  }

  Future<void> deleteEncode(Encode value) async {
    var items = getEncodes();
    await items.delete(value.key);
    return;
  }
}
