// UPC-A and UPC-E as printed: 12 and 8 digits, a UPC-A not as EAN-13.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/barcode/upc.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

Barcode _read(BarcodeFormat format, String text) => Barcode(
  format: format,
  text: text,
  bytes: Uint8List.fromList(text.codeUnits),
  position: const BarcodePosition(
    topLeft: Offset.zero,
    topRight: Offset.zero,
    bottomRight: Offset.zero,
    bottomLeft: Offset.zero,
  ),
  symbologyIdentifier: ']E0',
);

void main() {
  group('upcAsPrinted', () {
    test('an EAN-13 starting with 0 is a UPC-A of 12 digits', () {
      final Barcode b = upcAsPrinted(
        _read(BarcodeFormat.ean13, '0697929110035'),
        '',
      );
      expect(b.format, BarcodeFormat.upcA);
      expect(b.text, '697929110035');
      expect(b.bytes, '697929110035'.codeUnits);
      expect(b.symbologyIdentifier, ']E0');
    });

    test('with an add-on, it stays after the number', () {
      final Barcode b = upcAsPrinted(
        _read(BarcodeFormat.ean13, '069792911003512'),
        'EANUPC',
      );
      expect(b.format, BarcodeFormat.upcA);
      expect(b.text, '69792911003512');
    });

    test('other EAN-13s stay', () {
      final Barcode b = _read(BarcodeFormat.ean13, '4006381333931');
      expect(upcAsPrinted(b, ''), same(b));
    });

    test('asking for EAN-13 alone keeps EAN-13', () {
      final Barcode b = _read(BarcodeFormat.ean13, '0697929110035');
      expect(upcAsPrinted(b, 'EAN13'), same(b));
      expect(upcAsPrinted(b, 'EAN13,UPCA').format, BarcodeFormat.upcA);
    });

    test('a UPC-A asked for alone loses the leading zero too', () {
      final Barcode b = upcAsPrinted(
        _read(BarcodeFormat.upcA, '0697929110035'),
        'UPCA',
      );
      expect(b.text, '697929110035');
    });

    test('a UPC-E has its 8 digits', () {
      final Barcode b = upcAsPrinted(
        _read(BarcodeFormat.upcE, '0012345000065'),
        '',
      );
      expect(b.format, BarcodeFormat.upcE);
      expect(b.text, '01234565');
    });
  });

  test('UPC-A to UPC-E: the four zero-suppression rules', () {
    // Manufacturer ending in 000, 100 or 200: the third digit last.
    expect(upcEFromUpcA('012100000345'), '01203415');
    // Ending in 00: product's last two digits, then 3.
    expect(upcEFromUpcA('012300000455'), '01234535');
    // Ending in 0: product's last digit, then 4.
    expect(upcEFromUpcA('012340000057'), '01234547');
    // Product 0000 then 5-9: manufacturer and that digit.
    expect(upcEFromUpcA('012345000065'), '01234565');
    // Not suppressible.
    expect(upcEFromUpcA('697929110035'), isNull);
    expect(upcEFromUpcA('212345000065'), isNull);
  });

  group('human readable text, as GS1 prints it', () {
    BarcodeSymbol symbol(BarcodeFormat format, int width, String text) =>
        BarcodeSymbol(
          format: format,
          width: width,
          height: 10,
          modules: Uint8List(width * 10)
            ..fillRange(0, width * 10, 0)
            ..setAll(0, List<int>.filled(width, 1)),
          quietZone: 9,
          text: text,
        );

    test('EAN-13: the first digit outside, six under each half', () {
      final SymbolLayout layout = SymbolLayout(
        symbol(BarcodeFormat.ean13, 95, '4006381333931'),
      );
      final List<TextRun> runs = layout.textRuns;
      expect(runs.map((TextRun r) => r.text).join(), '4006381333931');
      expect(runs.first.x, lessThan(9));
      // Under the first character of each half: guard 3 + 3.5.
      expect(runs[1].x, 9 + 6.5);
      expect(runs[7].x, 9 + 53.5);
      expect(runs.every((TextRun r) => !r.fit), isTrue);
    });

    test('UPC-A: the outer digits outside and smaller', () {
      final List<TextRun> runs = SymbolLayout(
        symbol(BarcodeFormat.upcA, 95, '697929110035'),
      ).textRuns;
      expect(runs, hasLength(12));
      expect(runs.first.fontSize, lessThan(runs[1].fontSize));
      expect(runs.last.fontSize, lessThan(runs[1].fontSize));
      expect(runs.first.x, lessThan(9));
      expect(runs.last.x, greaterThan(9 + 95));
    });

    test('UPC-E and EAN-8', () {
      expect(
        SymbolLayout(symbol(BarcodeFormat.upcE, 51, '01234565')).textRuns,
        hasLength(8),
      );
      final List<TextRun> ean8 = SymbolLayout(
        symbol(BarcodeFormat.ean8, 67, '96385074'),
      ).textRuns;
      expect(ean8, hasLength(8));
      expect(ean8.first.x, 9 + 6.5);
    });

    test('without a quiet zone, the outer digits still get room', () {
      final SymbolLayout layout = SymbolLayout(
        BarcodeSymbol(
          format: BarcodeFormat.upcA,
          width: 95,
          height: 10,
          modules: Uint8List(950),
          text: '697929110035',
        ),
      );
      expect(layout.marginX, greaterThan(0));
      expect(layout.textRuns.first.x, greaterThan(0));
      expect(layout.textRuns.last.x, lessThan(layout.width));
    });

    test('other formats: one line, centred', () {
      final List<TextRun> runs = SymbolLayout(
        symbol(BarcodeFormat.code128, 60, 'ABC-123'),
      ).textRuns;
      expect(runs.single.text, 'ABC-123');
      expect(runs.single.fit, isTrue);
    });
  });
}
