// BarcodeFormat against zxing-cpp's own list of formats: every format the
// engine can report has a counterpart, with the same id and name.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/src/barcode/barcode_format.dart';

void main() {
  const String header = 'third_party/zxing-cpp/core/src/BarcodeFormat.h';

  test('every zxing-cpp format has a BarcodeFormat', () {
    final String source = File(header).readAsStringSync();
    final Iterable<RegExpMatch> formats = RegExp(
      r"X\((\w+),\s*'(.)',\s*'(.)'",
    ).allMatches(source);
    expect(formats, isNotEmpty);
    final List<String> missing = <String>[];
    for (final RegExpMatch m in formats) {
      final String name = m[1]!;
      final String symbol = m[2]!;
      final String variant = m[3]!;
      // Groups (All, AllLinear, ...) and the placeholder for formats from
      // other libraries are never reported for a barcode.
      if (symbol == '*' || name == 'OtherBarcode') {
        continue;
      }
      final int id = symbol.codeUnitAt(0) | (variant.codeUnitAt(0) << 8);
      final BarcodeFormat format = BarcodeFormatInternal.fromId(id);
      if (format == BarcodeFormat.unknown || format.zxingName != name) {
        missing.add('$name ($symbol$variant) -> ${format.name}');
      }
    }
    expect(missing, isEmpty);
  });

  test('Telepen variants belong to Telepen (found by the format catalog)', () {
    expect(BarcodeFormat.telepenAlpha.symbology, BarcodeFormat.telepen);
    expect(BarcodeFormat.telepenNumeric.symbology, BarcodeFormat.telepen);
    expect(BarcodeFormat.telepenAlpha.isLinear, isTrue);
  });
}
