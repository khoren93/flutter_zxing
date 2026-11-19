// BarcodeFormat against zxing-cpp's own list of formats: every format the
// engine can report has a counterpart, with the same id and name.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/src/barcode/barcode_format.dart';
import 'package:flutter_zxing/src/barcode/barcode_input.dart';

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

  test('canWrite is what zxing-cpp creates (its zint column), with the '
      'documented exceptions', () {
    final String source = File(header).readAsStringSync();
    final Set<BarcodeFormat> creatable = <BarcodeFormat>{
      for (final RegExpMatch m in RegExp(
        r"""X\((\w+),\s*'(.)',\s*'(.)',\s*"[^"]*",\s*(\d+),""",
      ).allMatches(source))
        if (m[2] != '*' && int.parse(m[4]!) != 0)
          BarcodeFormatInternal.fromId(
            m[2]!.codeUnitAt(0) | (m[3]!.codeUnitAt(0) << 8),
          ),
    };
    expect(creatable, isNotEmpty);
    // Created by zint, but not as a symbol of their own (EAN-2/5 add-ons),
    // unreadable as our module raster (ITF-14 bearer bars against the
    // bars) or not made of square modules (MaxiCode).
    const Set<BarcodeFormat> left = <BarcodeFormat>{
      BarcodeFormat.ean2,
      BarcodeFormat.ean5,
      BarcodeFormat.itf14,
      BarcodeFormat.maxiCode,
    };
    expect(<BarcodeFormat>{
      for (final BarcodeFormat f in BarcodeFormat.values)
        if (f.canWrite) f,
    }, creatable.difference(left));
  });

  test('writable lists every writable format once, without the variants a '
      'listed format creates', () {
    expect(
      BarcodeFormat.writable.every((BarcodeFormat f) => f.canWrite),
      isTrue,
    );
    expect(
      <BarcodeFormat>{
        for (final BarcodeFormat f in BarcodeFormat.values)
          if (f.canWrite && !BarcodeFormat.writable.contains(f)) f,
      },
      <BarcodeFormat>{
        BarcodeFormat.qrCodeModel2,
        BarcodeFormat.code39Standard,
        BarcodeFormat.aztecCode,
        BarcodeFormat.eanUpc,
        BarcodeFormat.dataBarOmni,
        BarcodeFormat.telepenAlpha,
        BarcodeFormat.telepenNumeric,
      },
    );
  });

  test('every writable format describes its input, no other does', () {
    for (final BarcodeFormat f in BarcodeFormat.values) {
      final BarcodeInput? input = f.input;
      expect(input != null, f.canWrite, reason: f.name);
      if (input != null) {
        expect(input.description, isNotEmpty, reason: f.name);
        expect(input.example, isNotEmpty, reason: f.name);
        if (input.digitsOnly) {
          expect(input.example, matches(RegExp(r'^\d+$')), reason: f.name);
        }
      }
    }
  });

  test('error correction is offered only where a level can be chosen', () {
    expect(
      <BarcodeFormat>{
        for (final BarcodeFormat f in BarcodeFormat.values)
          if (f.hasErrorCorrection) f,
      }.every((BarcodeFormat f) => f.canWrite && f.isMatrix),
      isTrue,
    );
    expect(BarcodeFormat.dataMatrix.hasErrorCorrection, isFalse);
    expect(BarcodeFormat.microPdf417.hasErrorCorrection, isFalse);
  });

  test('DX Film Edge, without a base format, is its own symbology', () {
    expect(BarcodeFormat.dxFilmEdge.symbology, BarcodeFormat.dxFilmEdge);
    expect(BarcodeFormat.unknown.symbology, BarcodeFormat.unknown);
  });
}
