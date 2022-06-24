import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

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

  Future<void> deleteCodes() async {
    final Box<Code> items = getCodes();
    await items.deleteAll(items.keys);
  }

  Future<int> addCode(Code value) async {
    final Box<Code> items = getCodes();
    if (!items.values.contains(value)) {
      return items.add(value);
    }
    return -1;
  }

  Future<void> deleteCode(Code value) async {
    final Box<Code> items = getCodes();
    await items.delete(value.key);
    return;
  }

  Box<Encode> getEncodes() => Hive.box<Encode>('encodes');

  Future<void> deleteEncodes() async {
    final Box<Encode> items = getEncodes();
    await items.deleteAll(items.keys);
  }

  Future<int> addEncode(Encode value) async {
    final Box<Encode> items = getEncodes();
    if (!items.values.contains(value)) {
      return items.add(value);
    }
    return -1;
  }

  Future<void> deleteEncode(Encode value) async {
    final Box<Encode> items = getEncodes();
    await items.delete(value.key);
    return;
  }
}
