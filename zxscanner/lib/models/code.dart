import 'package:flutter_zxing/flutter_zxing.dart' as zxing;
import 'package:hive_flutter/hive_flutter.dart';

part 'code.g.dart';

@HiveType(typeId: 0)
class Code extends HiveObject {
  Code();

  Code.fromCodeResult(zxing.Code result) {
    isValid = result.isValid;
    format = result.format;
    text = result.text;
  }
  @HiveField(0)
  bool? isValid;

  @HiveField(1)
  int? format;

  @HiveField(2)
  String? text;

  String get formatName => zxing.zx.barcodeFormatName(format ?? 0);
}
