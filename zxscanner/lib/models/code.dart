import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'code.g.dart';

@HiveType(typeId: 0)
class Code extends HiveObject {
  @HiveField(0)
  bool? isValid;

  @HiveField(1)
  int? format;

  @HiveField(2)
  String? text;

  Code();

  Code.fromCodeResult(CodeResult result) {
    isValid = result.isValidBool;
    format = result.format;
    text = result.textString;
  }

  String get formatName => barcodeFormatName(format ?? 0);
}
