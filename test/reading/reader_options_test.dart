import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  group('toString', () {
    test('ReaderOptions shows what differs from the defaults', () {
      expect(const ReaderOptions().toString(), 'ReaderOptions()');
      expect(
        const ReaderOptions.camera().toString(),
        'ReaderOptions(tryInvert: false)',
      );
      expect(
        const ReaderOptions(
          tryDenoise: true,
          isPure: true,
          binarizer: Binarizer.boolCast,
          minLineCount: 3,
          eanAddOn: EanAddOn.read,
          characterSet: CharacterSet.cp1251,
        ).toString(),
        'ReaderOptions(tryDenoise: true, isPure: true, binarizer: boolCast, '
        'minLineCount: 3, '
        'eanAddOn: read, characterSet: cp1251)',
      );
    });

    test('BarcodeReader shows its formats and options', () {
      expect(const BarcodeReader().toString(), 'BarcodeReader()');
      expect(
        const BarcodeReader(
          formats: <BarcodeFormat>{BarcodeFormat.qrCode, BarcodeFormat.ean13},
          options: ReaderOptions.camera(),
        ).toString(),
        'BarcodeReader(formats: {qrCode, ean13}, '
        'options: ReaderOptions(tryInvert: false))',
      );
    });
  });

  test('copyWith cannot clear formats: create a new reader', () {
    const BarcodeReader qr = BarcodeReader(
      formats: <BarcodeFormat>{BarcodeFormat.qrCode},
      options: ReaderOptions(isPure: true),
    );
    // null means "keep": the formats stay.
    expect(qr.copyWith().formats, <BarcodeFormat>{BarcodeFormat.qrCode});
    final BarcodeReader all = BarcodeReader(options: qr.options);
    expect(all.formats, isNull);
    expect(all.options, qr.options);
  });

  test('CharacterSet numbers are the ones of zxing-cpp', () {
    // The engine takes a CharacterSet by its number: the order of
    // zxing-cpp's enum, matched here by name.
    final String header = File(
      'third_party/zxing-cpp/core/src/CharacterSet.h',
    ).readAsStringSync();
    final String body = RegExp(
      r'enum class CharacterSet[^{]*\{([^}]*)\}',
    ).firstMatch(header)![1]!;
    final List<String> names = RegExp(
      r'^\s*(\w+),',
      multiLine: true,
    ).allMatches(body).map((RegExpMatch m) => m[1]!).toList();
    expect(names.first, 'Unknown');
    String key(String name) => name.toLowerCase().replaceAll('_', '');
    final Map<String, int> zxing = <String, int>{
      for (final (int i, String name) in names.indexed) key(name): i,
    };
    for (final CharacterSet c in CharacterSet.values) {
      expect(zxing[key(c.name)], c.engineId, reason: c.name);
    }
    // Every character set zxing-cpp decodes, but for Unknown (null) and
    // BINARY (no text).
    expect(
      names.where((String n) => n != 'Unknown' && n != 'BINARY'),
      hasLength(CharacterSet.values.length),
    );
  });
}
