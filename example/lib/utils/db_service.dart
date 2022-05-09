import 'package:flutter_zxing_example/models/models.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DbService {
  DbService._privateConstructor();

  static final DbService instance = DbService._privateConstructor();

  Future<void> initializeApp() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CodeAdapter());

    await Hive.openBox<Code>('codes');
    await Hive.openBox<Encode>('encodes');

    // Hive.box('codes').close();
  }

  Box<Code> getCodes() => Hive.box<Code>('codes');

  Future deleteCodes() async {
    var codes = getCodes();
    await codes.deleteAll(codes.keys);
    return;
  }

  Future addCode(Code value) async {
    var codes = getCodes();
    if (!codes.values.contains(value)) {
      return codes.add(value);
    }
    return;
  }

  Box<Encode> getEncodes() => Hive.box<Encode>('encodes');

  Future deleteEncodes() async {
    var encodes = getEncodes();
    await encodes.deleteAll(encodes.keys);
    return;
  }

  Future addEncode(Encode value) async {
    var encodes = getEncodes();
    if (!encodes.values.contains(value)) {
      return encodes.add(value);
    }
    return;
  }
}
