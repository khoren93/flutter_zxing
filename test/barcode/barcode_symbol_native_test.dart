// Barcode.symbol: the grid of modules the reader sampled. A code created by
// BarcodeWriter and read back gives exactly the modules it was created with.
@Tags(<String>['native'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  setUpAll(warmUpBarcodeEngine);

  Future<(BarcodeSymbol, Barcode?)> roundTrip(
    BarcodeFormat format,
    String text,
  ) async {
    final BarcodeWriter writer = BarcodeWriter(format);
    final BarcodeSymbol written = await writer.encode(text);
    final BarcodeImage image = await writer.toImage(text, moduleSize: 4);
    final Barcode? read = await BarcodeReader(
      formats: <BarcodeFormat>{format},
    ).read(await image.toPng());
    return (written, read);
  }

  for (final (BarcodeFormat format, String text) in <(BarcodeFormat, String)>[
    (BarcodeFormat.qrCode, 'https://pub.dev/packages/flutter_zxing'),
    (BarcodeFormat.dataMatrix, 'flutter_zxing 4.0'),
    (BarcodeFormat.aztec, 'flutter_zxing 4.0'),
  ]) {
    test('${format.displayName}: the modules as written', () async {
      final (BarcodeSymbol written, Barcode? read) = await roundTrip(
        format,
        text,
      );
      final BarcodeSymbol symbol = read!.symbol!;
      expect(symbol.format.symbology, format);
      expect(symbol.width, written.width);
      expect(symbol.height, written.height);
      expect(symbol.modules, written.modules);
    });
  }

  // Read at their centres, rounded and circular finder rings are white in
  // their corners: the read grid gets them back from the specification.
  for (final FinderShape finder in <FinderShape>[
    FinderShape.rounded,
    FinderShape.circle,
  ]) {
    // From version 1 up to past version 32, whose alignment patterns are
    // spaced unlike the others.
    for (final int length in <int>[5, 40, 300, 900, 1400]) {
      test('QR Code with ${finder.name} finders, $length characters: '
          'the modules as written', () async {
        const BarcodeWriter writer = BarcodeWriter(BarcodeFormat.qrCode);
        final BarcodeSymbol written = await writer.encode(
          List<String>.generate(length, (int i) => 'abcdefghij'[i % 10]).join(),
        );
        final Uint8List png = await written.toPng(
          moduleSize: 6,
          style: BarcodeStyle(
            finderShape: finder,
            moduleShape: ModuleShape.rounded,
          ),
        );
        final Barcode? read = await const BarcodeReader(
          formats: <BarcodeFormat>{BarcodeFormat.qrCode},
        ).read(png);
        expect(read!.symbol!.width, written.width);
        expect(read.symbol!.modules, written.modules);
      });
    }
  }

  test('PDF417 has no grid: zxing-cpp reads it by its bar widths', () async {
    final (BarcodeSymbol _, Barcode? read) = await roundTrip(
      BarcodeFormat.pdf417,
      'flutter_zxing 4.0 PDF417',
    );
    expect(read!.text, 'flutter_zxing 4.0 PDF417');
    expect(read.symbol, isNull);
  });

  test('linear codes have no grid', () async {
    final (BarcodeSymbol _, Barcode? read) = await roundTrip(
      BarcodeFormat.ean13,
      '5901234123457',
    );
    expect(read!.text, '5901234123457');
    expect(read.symbol, isNull);
  });
}
